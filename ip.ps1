param(
    [Parameter()][Alias("a")][string]$Adapter = "eth1",
    [Parameter()][Alias("p")][string]$Profile
)

$targetAdapter = $Adapter

function Show-AllAdapters {
    Write-Host "=== All Network Adapters ===" -ForegroundColor Magenta
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" -or $_.InterfaceDescription -match "Ethernet" -or $_.InterfaceDescription -match "有线" }
    foreach ($adapter in $adapters) {
        $alias = $adapter.InterfaceAlias
        $ipConfig = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dns = Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $ipInterface = Get-NetIPInterface -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dhcp = $ipInterface.Dhcp

        $linkStatus = if ($adapter.Status -eq "Up" -and $adapter.LinkSpeed -and $adapter.LinkSpeed -ne "Unknown") { "up" } else { "down" }
        $adminStatus = if ($adapter.Status -ne "Disabled") { "enabled" } else { "disabled" }

        Write-Host ""
        Write-Host "  [$alias] $adminStatus, $linkStatus" -ForegroundColor Cyan
        if ($ipConfig) {
            Write-Host "    IP:     $($ipConfig.IPAddress)" -ForegroundColor Yellow
            Write-Host "    PrefixLength: $($ipConfig.PrefixLength)"
        } else {
            Write-Host "    IP:     (none)" -ForegroundColor Gray
        }
        Write-Host "    DHCP:   $($dhcp)"
        if ($dns.ServerAddresses -and $dns.ServerAddresses -ne "0.0.0.0") {
            Write-Host "    DNS:    $($dns.ServerAddresses -join ', ')" -ForegroundColor Green
        }
    }
}

function Show-RoutingTable {
    Write-Host ""
    Write-Host "=== Routing Table ===" -ForegroundColor Magenta
    $routes = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -ne "0.0.0.0/0" -and $_.RouteMetric -lt 300 } | Sort-Object -Property RouteMetric | Select-Object -First 10
    foreach ($route in $routes) {
        $gw = if ($route.NextHop -eq "::") { "direct" } else { $route.NextHop }
        $iface = $route.InterfaceAlias
        Write-Host "  $($route.DestinationPrefix) via $gw dev $iface" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "=== Default Gateway ===" -ForegroundColor Magenta
    $gateways = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Sort-Object -Property RouteMetric
    if ($gateways) {
        foreach ($gw in $gateways) {
            Write-Host "  $($gw.NextHop) dev $($gw.InterfaceAlias) metric $($gw.RouteMetric)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }
}

function Clear-IPConflict {
    param($ipToCheck, $newIp)

    $conflicting = Get-NetIPAddress -IPAddress $ipToCheck -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -ne $targetAdapter }
    if ($conflicting) {
        $otherAdapter = $conflicting.InterfaceAlias
        Write-Host "  [$otherAdapter] already uses $ipToCheck, moving it to $newIp ..." -ForegroundColor Yellow
        $mask = "255.255.255.0"
        $result = netsh interface ip set address $otherAdapter static $newIp $mask 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Failed to update [$otherAdapter]: $result" -ForegroundColor Red
            return $false
        }
        Write-Host "  [$otherAdapter] updated to $newIp" -ForegroundColor Green
    }
    return $true
}

if (-not $Profile) {
    Show-AllAdapters
    Show-RoutingTable
    Write-Host ""
    Write-Host "Usage: .\ip.ps1 -Adapter <name> -Profile <1|2>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  -Adapter:  Network adapter name (default: eth1)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Profile 1: Static IP" -ForegroundColor Cyan
    Write-Host "    IP:   192.168.137.1" -ForegroundColor White
    Write-Host "    Mask: 255.255.255.0" -ForegroundColor White
    Write-Host "    DNS:  DHCP" -ForegroundColor White
    Write-Host ""
    Write-Host "  Profile 2: DHCP + Custom DNS" -ForegroundColor Cyan
    Write-Host "    IP:   DHCP" -ForegroundColor White
    Write-Host "    DNS:  176.16.98.100" -ForegroundColor White
    exit 0
}

$profile = $Profile
$hasError = $false
$targetIp = "192.168.137.1"
$altIp = "192.168.137.10"
$mask = "255.255.255.0"

if ($profile -eq "1") {
    Write-Host "Profile 1: Setting [$targetAdapter] to static IP: $targetIp / $mask ..." -ForegroundColor Cyan

    if (-not (Clear-IPConflict -ipToCheck $targetIp -newIp $altIp)) {
        $hasError = $true
    }

    if (-not $hasError) {
        Write-Host "  Setting [$targetAdapter] IP to static $targetIp / $mask ..." -ForegroundColor Gray
        $result = netsh interface ip set address $targetAdapter static $targetIp $mask 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Failed: $result" -ForegroundColor Red
            $hasError = $true
        }

        Write-Host "  Setting [$targetAdapter] DNS to DHCP ..." -ForegroundColor Gray
        netsh interface ip set dns $targetAdapter dhcp 2>&1 | Out-Null
    }

} elseif ($profile -eq "2") {
    $dns = "176.16.98.100"
    Write-Host "Profile 2: Setting [$targetAdapter] to DHCP + DNS: $dns ..." -ForegroundColor Cyan

    $dhcpCurrent = (Get-NetIPInterface -InterfaceAlias $targetAdapter -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    if ($null -ne $dhcpCurrent -and $dhcpCurrent.Dhcp -eq "Enabled") {
        Write-Host "  [$targetAdapter] DHCP already enabled, skipping ..." -ForegroundColor Gray
    } else {
        Write-Host "  Setting [$targetAdapter] IP to DHCP ..." -ForegroundColor Gray
        $result1 = netsh interface ip set address $targetAdapter dhcp 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Failed to set DHCP: $result1" -ForegroundColor Red
            $hasError = $true
        }
    }

    Write-Host "  Setting [$targetAdapter] DNS to $dns ..." -ForegroundColor Gray
    $result2 = netsh interface ip set dns $targetAdapter static $dns 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed to set DNS: $result2" -ForegroundColor Red
        $hasError = $true
    }

} else {
    Write-Host "Unknown profile: $profile" -ForegroundColor Red
    Write-Host "Usage: .\ip.ps1 -Adapter <name> -Profile <1|2>" -ForegroundColor Yellow
    exit 1
}

if (-not $hasError) {
    Write-Host ""
    Write-Host "Done!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some operations failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Show-AllAdapters
Show-RoutingTable
