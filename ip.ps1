param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1)][string]$AdapterArg,
    [Parameter(Position=2)][string]$ThirdArg,
    [Parameter()][Alias("p")][string]$ProfileNum
)

if ($Command -eq "set_profile") {
    $ProfileNum = $AdapterArg
    $targetAdapter = $ThirdArg
} elseif ($ProfileNum -and $Command -ne "" -and $AdapterArg -eq "") {
    $targetAdapter = $Command
} elseif ($Command -eq "-p" -or $Command -eq "p") {
    $targetAdapter = $ThirdArg
} elseif ($ProfileNum) {
    $targetAdapter = $ThirdArg
} else {
    $targetAdapter = $AdapterArg
}

function Show-AllAdapters {
    Write-Host "`n=== Network Adapters (IPv4/IPv6) ===" -ForegroundColor Magenta
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Sort-Object -Property Status, InterfaceAlias
    
    foreach ($adapter in $adapters) {
        $alias = $adapter.InterfaceAlias
        $adminStatus = if ($adapter.Status -ne "Disabled") { "enabled" } else { "disabled" }
        $linkStatus = if ($adapter.Status -eq "Up") { "up" } else { "down" }
        $linkSpeed = if ($adapter.LinkSpeed) { $adapter.LinkSpeed } else { "N/A" }
        
        $ipConfig = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dns = Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $ipInterface = Get-NetIPInterface -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dhcp = $ipInterface.Dhcp

        $isApipa = $ipConfig -and $ipConfig.IPAddress -like "169.254.*.*"
        $hasValidIp = $ipConfig -and -not $isApipa
        
        $statusColor = if ($hasValidIp) { "Green" } elseif ($isApipa) { "Yellow" } elseif ($linkStatus -eq "up") { "White" } else { "Gray" }
        $ipStatus = if ($hasValidIp) { "valid IP" } elseif ($isApipa) { "APIPA (no DHCP)" } elseif ($ipConfig) { "no DHCP" } else { "no IP" }

        Write-Host ""
        Write-Host "  [$alias]" -NoNewline
        Write-Host " $adminStatus, $linkStatus, $linkSpeed" -ForegroundColor Cyan

        
        if ($ipConfig) {
            Write-Host "    IPv4: $($ipConfig.IPAddress)/$($ipConfig.PrefixLength)" -ForegroundColor $(if ($hasValidIp) { "Cyan" } else { "Gray" })
        } else {
            Write-Host "    IPv4: (none)" -ForegroundColor Gray
        }
        Write-Host "    DHCP: $dhcp"
        if ($dns.ServerAddresses -and $dns.ServerAddresses[0] -ne "0.0.0.0") {
            Write-Host "    DNS:  $($dns.ServerAddresses -join ', ')" -ForegroundColor Green
        }
        
        $ipConfigV6 = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne "WellKnown" }
        $gatewayV6 = Get-NetRoute -InterfaceAlias $alias -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "::/0" } | Select-Object -First 1
        
        if ($ipConfigV6 -or $gatewayV6) {
            if ($ipConfigV6) {
                foreach ($ip in $ipConfigV6) {
                    Write-Host "    IPv6: $($ip.IPAddress)/$($ip.PrefixLength)" -ForegroundColor Cyan
                }
            }
            if ($gatewayV6) {
                Write-Host "    IPv6 Gateway: $($gatewayV6.NextHop)" -ForegroundColor Green
            }
        }
    }
}

function Show-RoutingTable {
    Write-Host "`n=== IPv4 Routing Table ===" -ForegroundColor Magenta
    $routes = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { 
        $_.DestinationPrefix -ne "0.0.0.0/0" -and 
        $_.RouteMetric -lt 300 -and
        $_.DestinationPrefix -notlike "224.*" -and
        $_.DestinationPrefix -notlike "127.*"
    } | Sort-Object -Property RouteMetric | Select-Object -First 15
    
    foreach ($route in $routes) {
        $gw = if ($route.NextHop -eq "0.0.0.0") { "direct" } else { $route.NextHop }
        $iface = $route.InterfaceAlias
        Write-Host "  $($route.DestinationPrefix) via $gw dev $iface metric $($route.RouteMetric)" -ForegroundColor Cyan
    }

    Write-Host "`n=== Default Gateway ===" -ForegroundColor Magenta
    $gateways = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Sort-Object -Property RouteMetric
    if ($gateways) {
        foreach ($gw in $gateways) {
            $color = if ($gw.RouteMetric -eq ($gateways | Measure-Object -Property RouteMetric -Minimum).Minimum) { "Yellow" } else { "White"
            }
            Write-Host "  $($gw.NextHop) dev $($gw.InterfaceAlias) metric $($gw.RouteMetric)" -ForegroundColor $color
        }
    } else {
        Write-Host "  (none)" -ForegroundColor Red
    }
    
    Write-Host "`n=== IPv6 Routing Table ===" -ForegroundColor Magenta
    $routesV6 = Get-NetRoute -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object { 
        $_.DestinationPrefix -ne "::/0" -and
        $_.RouteMetric -lt 300
    } | Sort-Object -Property RouteMetric | Select-Object -First 10
    
    foreach ($route in $routesV6) {
        Write-Host "  $($route.DestinationPrefix) via $($route.NextHop) dev $($route.InterfaceAlias) metric $($route.RouteMetric)" -ForegroundColor Cyan
    }
    
    $gatewayV6 = Get-NetRoute -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "::/0" }
    if ($gatewayV6) {
        Write-Host "`n=== IPv6 Default Gateway ===" -ForegroundColor Magenta
        foreach ($gw in $gatewayV6) {
            Write-Host "  $($gw.NextHop) dev $($gw.InterfaceAlias) metric $($gw.RouteMetric)" -ForegroundColor Yellow
        }
    }
}

function Test-NetworkConnectivity {
    param(
        [string]$Target = "8.8.8.8",
        [string]$Description = "Google DNS",
        [string]$Gateway = ""
    )
    
    Write-Host "`n=== Network Connectivity Test ===" -ForegroundColor Magenta
    
    $defaultGateway = (Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Sort-Object -Property RouteMetric -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
    if ($Gateway) {
        Write-Host "Testing gateway: $Gateway ... " -NoNewline
        $result = Test-Connection -ComputerName $Gateway -Count 2 -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
        }
    } elseif ($defaultGateway) {
        Write-Host "Testing gateway: $defaultGateway ... " -NoNewline
        $result = Test-Connection -ComputerName $defaultGateway -Count 2 -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host "FAILED" -ForegroundColor Red
        }
    }
    
    Write-Host "Testing $Target ($Description) ... " -NoNewline
    $result = Test-Connection -ComputerName $Target -Count 2 -ErrorAction SilentlyContinue
    if ($result) {
        $avg = ($result.ResponseTime | Measure-Object -Average).Average
        Write-Host "OK (avg: ${avg}ms)" -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
    }
}

function Add-StaticRoute {
    param(
        [string]$Destination,
        [string]$Mask = "255.255.255.255",
        [string]$Gateway,
        [string]$InterfaceIndex
    )
    
    if (-not $Gateway) {
        $gateway = (Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Sort-Object -Property RouteMetric | Select-Object -First 1).NextHop
        if (-not $gateway) {
            Write-Host "Error: No default gateway found" -ForegroundColor Red
            return $false
        }
        $Gateway = $gateway
    }
    
    Write-Host "Adding route: $Destination/$Mask via $Gateway" -ForegroundColor Cyan
    try {
        if ($InterfaceIndex) {
            New-NetRoute -DestinationPrefix "$Destination/$Mask" -NextHop $Gateway -InterfaceIndex $InterfaceIndex -RouteMetric 10 -ErrorAction Stop
        } else {
            New-NetRoute -DestinationPrefix "$Destination/$Mask" -NextHop $Gateway -RouteMetric 10 -ErrorAction Stop
        }
        Write-Host "Route added successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to add route: $_" -ForegroundColor Red
        return $false
    }
}

function Remove-StaticRoute {
    param(
        [string]$Destination
    )
    
    Write-Host "Removing route: $Destination" -ForegroundColor Cyan
    try {
        $route = Get-NetRoute -DestinationPrefix $Destination -ErrorAction SilentlyContinue
        if ($route) {
            Remove-NetRoute -DestinationPrefix $Destination -Confirm:$false -ErrorAction Stop
            Write-Host "Route removed successfully" -ForegroundColor Green
        } else {
            Write-Host "Route not found" -ForegroundColor Yellow
        }
        return $true
    } catch {
        Write-Host "Failed to remove route: $_" -ForegroundColor Red
        return $false
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

function Set-FirstAdapter {
    param($adapterName)
    
    Write-Host "`n=== Setting [$adapterName] as primary network adapter ===" -ForegroundColor Magenta
    
    $targetAdapterObj = Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue
    if (-not $targetAdapterObj) {
        $targetAdapterObj = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
            $_.InterfaceAlias -eq $adapterName -or 
            $_.InterfaceDescription -match [regex]::Escape($adapterName) -or
            $_.Name -eq $adapterName 
        } | Select-Object -First 1
    }
    
    if (-not $targetAdapterObj) {
        Write-Host "  Error: Adapter [$adapterName] not found!" -ForegroundColor Red
        return $false
    }
    
    $targetAlias = $targetAdapterObj.InterfaceAlias
    Write-Host "  Found adapter: [$targetAlias]" -ForegroundColor Cyan
    
    $gateways = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" }
    
    if (-not $gateways) {
        Write-Host "  No default gateway found, will add one..." -ForegroundColor Yellow
        
        $ipConfig = Get-NetIPAddress -InterfaceAlias $targetAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if (-not $ipConfig) {
            Write-Host "  Error: Cannot get IP configuration for [$targetAlias]" -ForegroundColor Red
            return $false
        }
        
        $ipAddress = $ipConfig.IPAddress
        
        if ($ipAddress -like "169.254.*.*") {
            Write-Host "  Detected APIPA address ($ipAddress), refreshing DHCP..." -ForegroundColor Yellow
            ipconfig /release $targetAlias | Out-Null
            ipconfig /renew $targetAlias | Out-Null
            Start-Sleep -Seconds 3
            
            $ipConfig = Get-NetIPAddress -InterfaceAlias $targetAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if (-not $ipConfig) {
                Write-Host "  Error: Failed to renew DHCP address" -ForegroundColor Red
                return $false
            }
            $ipAddress = $ipConfig.IPAddress
            Write-Host "  Got new IP: $ipAddress" -ForegroundColor Green
        }
        
        $prefixLength = $ipConfig.PrefixLength
        $gateway = $null
        
        $ipParts = $ipAddress.Split('.')
        if ($ipParts.Count -eq 4) {
            $gateway = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).1"
        }
        
        if (-not $gateway) {
            Write-Host "  Error: Cannot determine gateway address" -ForegroundColor Red
            return $false
        }
        
        Write-Host "  Adding default gateway $gateway for [$targetAlias]..." -ForegroundColor Cyan
        try {
            New-NetRoute -InterfaceAlias $targetAlias -DestinationPrefix "0.0.0.0/0" -NextHop $gateway -RouteMetric 10 -ErrorAction Stop
            Write-Host "  Successfully added gateway $gateway" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to add gateway (requires admin): $_" -ForegroundColor Red
            return $false
        }
        
        Start-Sleep -Milliseconds 500
        $gateways = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" }
    }
    
    $targetGateway = $gateways | Where-Object { $_.InterfaceAlias -eq $targetAlias }
    if (-not $targetGateway) {
        Write-Host "  Error: No default gateway found for adapter [$targetAlias]" -ForegroundColor Red
        return $false
    }
    
    Write-Host "`n  Current default gateways:" -ForegroundColor Yellow
    foreach ($gw in $gateways | Sort-Object -Property RouteMetric) {
        Write-Host "    $($gw.NextHop) dev $($gw.InterfaceAlias) metric $($gw.RouteMetric)"
    }
    
    $minMetric = ($gateways.RouteMetric | Measure-Object -Minimum).Minimum
    $newTargetMetric = 10
    $otherMetric = 200
    
    Write-Host "`n  Setting [$targetAlias] gateway priority to highest..." -ForegroundColor Cyan
    
    foreach ($gw in $gateways) {
        if ($gw.InterfaceAlias -eq $targetAlias) {
            if ($gw.RouteMetric -ne $newTargetMetric) {
                Write-Host "    Updating [$targetAlias] metric from $($gw.RouteMetric) to $newTargetMetric..." -ForegroundColor Gray
                try {
                    Set-NetRoute -InterfaceAlias $targetAlias -DestinationPrefix "0.0.0.0/0" -NextHop $gw.NextHop -RouteMetric $newTargetMetric -ErrorAction Stop
                    Write-Host "    Successfully updated [$targetAlias] metric to $newTargetMetric" -ForegroundColor Green
                } catch {
                    Write-Host "    Failed to update [$targetAlias] metric (requires admin): $_" -ForegroundColor Red
                    return $false
                }
            } else {
                Write-Host "    [$targetAlias] already has highest priority (metric $newTargetMetric)" -ForegroundColor Gray
            }
        } else {
            if ($gw.RouteMetric -lt $otherMetric) {
                Write-Host "    Lowering [$($gw.InterfaceAlias)] metric from $($gw.RouteMetric) to $otherMetric..." -ForegroundColor Gray
                try {
                    Set-NetRoute -InterfaceAlias $gw.InterfaceAlias -DestinationPrefix "0.0.0.0/0" -NextHop $gw.NextHop -RouteMetric $otherMetric -ErrorAction Stop
                    Write-Host "    Successfully lowered [$($gw.InterfaceAlias)] metric to $otherMetric" -ForegroundColor Green
                } catch {
                    Write-Host "    Failed to update [$($gw.InterfaceAlias)] metric (requires admin): $_" -ForegroundColor Red
                }
            }
        }
    }
    
    Write-Host "`n  Updated default gateways:" -ForegroundColor Yellow
    $updatedGateways = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Sort-Object -Property RouteMetric
    foreach ($gw in $updatedGateways) {
        Write-Host "    $($gw.NextHop) dev $($gw.InterfaceAlias) metric $($gw.RouteMetric)"
    }
    
    return $true
}

if ($Command -eq "set_first") {
    if (-not $AdapterArg) {
        Write-Host "Error: Adapter name is required for set_first command!" -ForegroundColor Red
        Write-Host "Usage: .\ip.ps1 set_first <adapter_name>" -ForegroundColor Yellow
        exit 1
    }
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Warning: This command requires administrator privileges" -ForegroundColor Yellow
    }
    
    if (Set-FirstAdapter -adapterName $AdapterArg) {
        Write-Host "`nDone!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to set [$AdapterArg] as primary adapter" -ForegroundColor Red
        exit 1
    }
    exit 0
}

if ($Command -eq "ping") {
    $target = $AdapterArg
    $description = if ($ThirdArg) { $ThirdArg } elseif ($ProfileNum) { $ProfileNum } else { "" }
    
    if (-not $target) {
        $target = "8.8.8.8"
        $description = "Google DNS"
    } elseif (-not $description) {
        $description = "Custom Target"
    }
    
    Test-NetworkConnectivity -Target $target -Description $description
    exit 0
}

if ($Command -eq "route_add") {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Error: This command requires administrator privileges" -ForegroundColor Red
        exit 1
    }
    
    if (-not $AdapterArg) {
        Write-Host "Error: Usage: .\ip.ps1 route_add <destination> [gateway]" -ForegroundColor Red
        exit 1
    }
    
    $destination = $AdapterArg
    $gateway = $ProfileNum
    
    if (Add-StaticRoute -Destination $destination -Gateway $gateway) {
        Write-Host "`nRoute added!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to add route" -ForegroundColor Red
        exit 1
    }
    exit 0
}

if ($Command -eq "route_del") {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Error: This command requires administrator privileges" -ForegroundColor Red
        exit 1
    }
    
    if (-not $AdapterArg) {
        Write-Host "Error: Usage: .\ip.ps1 route_del <destination>" -ForegroundColor Red
        exit 1
    }
    
    if (Remove-StaticRoute -Destination $AdapterArg) {
        Write-Host "`nRoute removed!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to remove route" -ForegroundColor Red
        exit 1
    }
    exit 0
}

function Set-ICS {
    param(
        [string]$SrcAdapter,
        [string]$TargetAdapter
    )
    
    Write-Host "`n=== Configuring ICS: [$SrcAdapter] -> [$TargetAdapter] ===" -ForegroundColor Magenta
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Error: This command requires administrator privileges" -ForegroundColor Red
        return $false
    }
    
    # Verify adapters exist
    $srcAdapterObj = Get-NetAdapter -Name $SrcAdapter -ErrorAction SilentlyContinue
    if (-not $srcAdapterObj) {
        Write-Host "Error: Source adapter [$SrcAdapter] not found" -ForegroundColor Red
        return $false
    }
    
    $targetAdapterObj = Get-NetAdapter -Name $TargetAdapter -ErrorAction SilentlyContinue
    if (-not $targetAdapterObj) {
        Write-Host "Error: Target adapter [$TargetAdapter] not found" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Source adapter: $SrcAdapter" -ForegroundColor Cyan
    Write-Host "Target adapter: $TargetAdapter" -ForegroundColor Cyan
    Write-Host ""
    
    # Get current ICS configuration
    $netSharingMgr = New-Object -ComObject HNetCfg.HNetShare
    
    try {
        # Disable any existing sharing first
        foreach ($connection in $netSharingMgr.EnumEveryConnection) {
            $netShareCfg = $netSharingMgr.INetSharingConfigurationForINetConnection($connection)
            $props = $netSharingMgr.NetConnectionProps.INetConnectionProps($connection)
            
            if ($netShareCfg.SharingEnabled) {
                Write-Host "Disabling existing ICS on [$($props.Name)] ..." -ForegroundColor Yellow
                $netShareCfg.DisableSharing()
            }
        }
        
        # Enable ICS on source adapter (share out)
        $srcConnection = $null
        foreach ($connection in $netSharingMgr.EnumEveryConnection) {
            $props = $netSharingMgr.NetConnectionProps.INetConnectionProps($connection)
            if ($props.Name -eq $SrcAdapter) {
                $srcConnection = $connection
                break
            }
        }
        
        if ($srcConnection) {
            Write-Host "Enabling sharing on source adapter [$SrcAdapter] ..." -ForegroundColor Cyan
            $netShareCfg = $netSharingMgr.INetSharingConfigurationForINetConnection($srcConnection)
            $netShareCfg.EnableSharing(0)  # 0 = Private, 1 = Public
        } else {
            Write-Host "Warning: Could not find source adapter in ICS configuration" -ForegroundColor Yellow
        }
        
        # Enable ICS on target adapter (share in)
        $targetConnection = $null
        foreach ($connection in $netSharingMgr.EnumEveryConnection) {
            $props = $netSharingMgr.NetConnectionProps.INetConnectionProps($connection)
            if ($props.Name -eq $TargetAdapter) {
                $targetConnection = $connection
                break
            }
        }
        
        if ($targetConnection) {
            Write-Host "Enabling sharing on target adapter [$TargetAdapter] ..." -ForegroundColor Cyan
            $netShareCfg = $netSharingMgr.INetSharingConfigurationForINetConnection($targetConnection)
            $netShareCfg.EnableSharing(1)  # 0 = Private, 1 = Public
        } else {
            Write-Host "Warning: Could not find target adapter in ICS configuration" -ForegroundColor Yellow
        }
        
        # Set static IP on target adapter (192.168.137.1)
        Write-Host "Setting static IP 192.168.137.1/255.255.255.0 on target adapter [$TargetAdapter] ..." -ForegroundColor Cyan
        
        # Clear any conflicts
        if (-not (Clear-IPConflict -ipToCheck "192.168.137.1" -newIp "192.168.137.10")) {
            Write-Host "Warning: Could not clear IP conflicts" -ForegroundColor Yellow
        }
        
        $result = netsh interface ip set address $TargetAdapter static 192.168.137.1 255.255.255.0 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to set static IP on target: $result" -ForegroundColor Red
            return $false
        }
        
        Write-Host ""
        Write-Host "ICS configured successfully!" -ForegroundColor Green
        Write-Host "Source adapter: $SrcAdapter" -ForegroundColor Cyan
        Write-Host "Target adapter: $TargetAdapter" -ForegroundColor Cyan
        Write-Host "Target IP: 192.168.137.1" -ForegroundColor Cyan
        
        return $true
    } catch {
        Write-Host "Error configuring ICS: $_" -ForegroundColor Red
        return $false
    }
}

if ($Command -eq "set_ics") {
    if (-not $AdapterArg -or -not $ThirdArg) {
        Write-Host "Error: Usage: .\ip.ps1 set_ics <source_adapter> <target_adapter>" -ForegroundColor Red
        exit 1
    }
    
    if (Set-ICS -SrcAdapter $AdapterArg -TargetAdapter $ThirdArg) {
        Write-Host "`nICS configured successfully!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to configure ICS" -ForegroundColor Red
        exit 1
    }
    exit 0
}

if (-not $ProfileNum) {
    Show-AllAdapters
    Show-RoutingTable
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\ip.ps1                              Show all network info" -ForegroundColor White
    Write-Host "  .\ip.ps1 ping [target]                Test network connectivity" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_first <adapter>          Set adapter as primary (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 route_add <dest> [gateway]    Add static route (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 route_del <dest>              Delete route (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_profile <1|2> [adapter]  Apply network profile" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_ics <src> <target>       Configure ICS network sharing (requires admin)" -ForegroundColor White
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

$profile = $ProfileNum
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
    Write-Host "Usage: .\ip.ps1 -p <1|2> [adapter]" -ForegroundColor Yellow
    exit 1
}

if (-not $hasError) {
    Write-Host "`nDone!" -ForegroundColor Green
} else {
    Write-Host "`nSome operations failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Show-AllAdapters
Show-RoutingTable
