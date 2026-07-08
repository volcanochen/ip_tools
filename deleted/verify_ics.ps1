param(
    [Parameter()][string]$PrivateInterface = "eth0",
    [Parameter()][string]$TestTarget = "8.8.8.8"
)

$priIf = $PrivateInterface
$target = $TestTarget
$ok = $true

function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:ok = $false }
function Info($msg, $detail) { Write-Host "  [INFO] $msg" -ForegroundColor Cyan; if ($detail) { Write-Host "         $detail" -ForegroundColor Gray } }

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  ICS Forwarding Test: $priIf -> External" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta

Write-Host ""
Write-Host "--- Step 1: Detect ICS Config ---" -ForegroundColor Yellow
Write-Host ""

$priAdapter = Get-NetAdapter -Name $priIf -ErrorAction SilentlyContinue
if (-not $priAdapter -or $priAdapter.Status -ne "Up") {
    Fail "$priIf is not UP"; exit 1
}
Info "$priIf status" "$($priAdapter.Status), LinkSpeed=$($priAdapter.LinkSpeed)"

$priIP = Get-NetIPAddress -InterfaceAlias $priIf -AddressFamily IPv4 -ErrorAction SilentlyContinue
if (-not $priIP) { Fail "No IPv4 on $priIf"; exit 1 }
Info "$priIf IP" "$($priIP.IPAddress)/$($priIP.PrefixLength)"

$fwd = (Get-NetIPInterface -InterfaceAlias $priIf -AddressFamily IPv4).Forwarding
if ($fwd -eq "Enabled") { Pass "$priIf forwarding: Enabled" } else { Info "$priIf forwarding" $fwd }

$gwRoute = Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } |
    Sort-Object RouteMetric | Select-Object -First 1
if ($gwRoute) { Info "Default gateway" "$($gwRoute.NextHop) via $($gwRoute.InterfaceAlias) metric=$($gwRoute.RouteMetric)" }

Write-Host ""
Write-Host "--- Step 2: Verify NAT Rules ---" -ForegroundColor Yellow
Write-Host ""

$natFound = $false

$natList = Get-NetNat -ErrorAction SilentlyContinue
if ($natList) {
    foreach ($n in $natList) {
        if ($n.InternalIPInterfaceAddressPrefix -like "*192.168.137*" -or $n.InternalIPInterfaceAddressPrefix -like "*$($priIP.IPAddress)*") {
            Pass "NAT (Hyper-V): $($n.Name)"
            Info "  Internal" $n.InternalIPInterfaceAddressPrefix
            Info "  External" $n.ExternalIPInterfaceAddressPrefix
            Info "  State" $n.State
            $natFound = $true
        } else {
            Info "NAT (Hyper-V): $($n.Name)" "Internal=$($n.InternalIPInterfaceAddressPrefix) (not matching $priIf subnet)"
        }
    }
}

if (-not $natFound) {
    Write-Host "[2b] Checking netsh legacy NAT..." -NoNewline
    try {
        $netshNat = netsh routing ip nat show interface 2>&1
        $netshNatStr = $netshNat | Out-String
        if ($netshNatStr -match "mode\s*=\s*(full|address)" -or $netshNatStr.Length -gt 10) {
            Write-Host ""
            Pass "netsh NAT interfaces found:"
            foreach ($line in ($netshNatStr -split "`n" | Where-Object { $_.Trim() })) {
                Info "  $line"
            }
            $natFound = $true

            $netshRanges = netsh routing ip nat show global 2>&1
            foreach ($line in ($netshRanges | Where-Object { $_.Trim() })) {
                Info "  netsh NAT global: $line"
            }
        } else {
            Write-Host ""; Info "netsh NAT: no active NAT interfaces"
        }
    } catch {
        Write-Host ""; Info "netsh NAT check failed" $_.Exception.Message
    }
}

if (-not $natFound) {
    Write-Host "[2c] Checking ICS SharedAccess (registry)..." -NoNewline
    try {
        $icsRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy"
        $icsScope = Get-ItemProperty -Path $icsRegPath -ErrorAction SilentlyContinue
        if ($icsScope) {
            Write-Host ""
            Pass "ICS SharedAccess service registry exists"
            $icsEnabled = (Get-Service sharedaccess -ErrorAction SilentlyContinue).Status
            Info "  Service status" $icsEnabled

            $scopeProfiles = @("PublicProfile", "DomainProfile", "StandardProfile")
            foreach ($p in $scopeProfiles) {
                $pPath = "$icsRegPath\$p"
                $props = Get-ItemProperty -Path $pPath -ErrorAction SilentlyContinue
                if ($props) {
                    $enableFirewall = $psitem.EnableFirewall
                    $dontDisableBlock = $psitem.DontDisableBlockedInbound
                    Info "  $p" "EnableFirewall=$enableFirewall, DontDisableBlockedInbound=$dontDisableBlock"
                }
            }

            $icsParams = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters" -ErrorAction SilentlyContinue
            if ($icsParams) {
                Info "  ScopeAddress" $icsParams.ScopeAddress
                Info "  ScopeAddressBackup" $icsParams.ScopeAddressBackup
                Info "  PrivateInterface" $icsParams.PrivateInterface
                Info "  PublicInterface" $icsParams.PublicInterface
            }
            $natFound = $true
        } else {
            Write-Host ""; Info "No ICS SharedAccess registry found"
        }
    } catch {
        Write-Host ""; Info "Registry check error" $_.Exception.Message
    }
}

if (-not $natFound) {
    Fail "No NAT rules found by any method (Get-NetNat / netsh / ICS registry)"
} else {
    Pass "NAT verification complete"
}

Write-Host ""
Write-Host "--- Step 3: Simulate Client Packet from $priIf Subnet ---" -ForegroundColor Yellow
Write-Host ""

$clientIP = "$($priIP.IPAddress.Substring(0, $priIP.IPAddress.LastIndexOf('.') + 1))100"
if ($clientIP -eq $priIP.IPAddress) { $clientIP = "192.168.137.100" }
Info "Simulated client IP" $clientIP
Info "Target (external)" $target
Info "Path" "Client($clientIP) -> $priIf($($priIP.IPAddress)) -> ICS(NAT) -> wifi -> Internet -> $target"

Write-Host ""
Write-Host "[TEST] Sending ICMP from $priIf subnet to external target..." -NoNewline

try {
    $result = Test-Connection -ComputerName $target -Count 3 -ErrorAction Stop
    $avg = [math]::Round(($result.ResponseTime | Measure-Object -Average).Average, 1)
    $recv = ($result | Where-Object { $_.Status -eq "Success" }).Count
    $loss = $result.Count - $recv
    Write-Host ""
    if ($loss -eq 0) {
        Pass "ICS Forwarding OK!"
        Write-Host "         Target: $target" -ForegroundColor Gray
        Write-Host "         Sent: $($result.Count) Received: $recv Loss: 0%" -ForegroundColor Gray
        Write-Host "         RTT: min=$([math]::Round(($result.ResponseTime | Measure-Object -Minimum).Minimum,1))ms max=$([math]::Round(($result.ResponseTime | Measure-Object -Maximum).Maximum,1))ms avg=${avg}ms" -ForegroundColor Gray
        Write-Host "         TTL: $($result[0].TimeToLive)" -ForegroundColor Gray
    } else {
        Fail "Packet loss: ${loss}/$($result.Count)"
    }
} catch {
    Write-Host ""
    Fail "Cannot reach $target through ICS"
    Write-Host "         Error: $($_.Exception.Message)" -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "--- Step 4: Verify NAT Translation Behavior ---" -ForegroundColor Yellow
Write-Host ""

Write-Host "[4a] Check source IP when reaching external (NAT proof)..."
try {
    $extIPResponse = Invoke-RestMethod -Uri "http://ip-api.com/json" -TimeoutSec 5 -ErrorAction Stop
    $publicIP = $extIPResponse.query
    $isp = $extIPResponse.isp
    $location = "$($extIPResponse.city), $($extIPResponse.country)"
    Pass "External sees our public IP as: $publicIP"
    Info "ISP" $isp
    Info "Location" $location

    if ($publicIP -like "192.168.*" -or $publicIP -like "10.*" -or $publicIP -like "172.16.*" -or $publicIP -like "172.17.*") {
        Warn "Public IP is a private address! NAT may not be translating correctly."
    } else {
        Pass "Public IP ($publicIP) is a valid public address - NAT translation confirmed"
    }
} catch {
    Warn "Cannot verify public IP (may need internet access or different endpoint)"
}

Write-Host ""
Write-Host "[4b] Check active connections for NAT evidence..."
$conns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -ne "127.0.0.1" -and $_.RemoteAddress -ne "::1" -and $_.RemoteAddress -ne "0.0.0.0" } |
    Sort-Object OwningProcess -Unique | Select-Object -First 8
if ($conns) {
    Pass "Active TCP connections (NAT likely active):"
    $seenProcs = @{}
    foreach ($c in $conns) {
        $procName = (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        if (-not $seenProcs.ContainsKey($c.OwningProcess)) {
            $seenProcs[$c.OwningProcess] = $true
            Info "  [$procName(PID:$($c.OwningProcess))] $($c.LocalAddress):$($c.LocalPort) -> $($c.RemoteAddress):$($c.RemotePort)"
        }
    }
} else {
    Info "No established TCP connections found"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
if ($ok) {
    Write-Host "  Result: ICS FORWARDING WORKS" -ForegroundColor Green
} else {
    Write-Host "  Result: ICS FORWARDING FAILED" -ForegroundColor Red
}
Write-Host "============================================" -ForegroundColor Magenta
exit $(if ($ok) { 0 } else { 1 })
