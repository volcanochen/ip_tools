param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1)][string]$AdapterArg,
    [Parameter(Position=2)][string]$ThirdArg,
    [Parameter(Position=3)][string]$FourthArg,
    [Parameter()][Alias("p")][string]$ProfileNum,
    [Parameter()][Alias("d")][string]$NatDest,
    [Parameter()][switch]$Persist,
    [Parameter()][Alias("dev")][string]$DevInterface
)

# 定义 Trace-Route 函数（必须在命令处理逻辑之前）
function Trace-Route {
    param(
        [string]$Target,
        [string]$Description = "目标主机",
        [string]$Gateway = ""
    )
    
    Write-Host "`n=== 网络路由追踪 (Traceroute) ===" -ForegroundColor Magenta
    
    # 检查 tracert 是否可用（需要管理员权限）
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "⚠️  注意：tracert 需要管理员权限才能显示完整的路由信息" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # 使用 PowerShell 内置的 Test-NetPathConnection 进行路由追踪（不需要管理员）
    Write-Host "`n=== 使用 PowerShell 网络测试 (替代 tracert) ===" -ForegroundColor Cyan
    
    if ($Gateway) {
        Write-Host "Testing connectivity to $Target via gateway $Gateway ... " -NoNewline
        try {
            # 显示 DNS 解析信息
            Write-Host "`nDNS 解析:" -ForegroundColor Gray
            $resolved = Resolve-DnsName -Name $Target -Type A -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($resolved) {
                Write-Host "  $($resolved.Name) -> $($resolved.AddressString)" -ForegroundColor Gray
            } else {
                Write-Host "  DNS 解析失败" -ForegroundColor Yellow
            }
            
            # 测试网络连通性
            Write-Host "`n网络测试:" -ForegroundColor Gray
            $pingResult = Test-NetConnection -ComputerName $Target -Port 80 -InformationLevel Detailed
            if ($pingResult) {
                Write-Host "✓ 目标地址：$($pingResult.RemoteAddress)" -ForegroundColor Green
                Write-Host "  状态：$($pingResult.Status)" -ForegroundColor Gray
                Write-Host "  往返时间：${($pingResult.RoundTripTime)}ms" -ForegroundColor Gray
            } else {
                Write-Host "✗ 无法连接到目标" -ForegroundColor Red
            }
            
            # 显示路由信息（如果可用）
            try {
                $route = Get-NetRoute -DestinationPrefix $Target -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($route) {
                    Write-Host "`n路由信息:" -ForegroundColor Gray
                    Write-Host "  目标：$($route.DestinationPrefix)/$($route.PrefixLength)" -ForegroundColor Gray
                    Write-Host "  网关：$($route.NextHop)" -ForegroundColor Gray
                    Write-Host "  接口：$($route.InterfaceAlias)" -ForegroundColor Gray
                } else {
                    Write-Host "`n未找到特定路由（使用默认网关）" -ForegroundColor Yellow
                }
            } catch {}
            
        } catch {
            Write-Host "✗ 测试失败：$_" -ForegroundColor Red
        }
    } else {
        Write-Host "Testing connectivity to $Target ... " -NoNewline
        try {
            # 显示 DNS 解析信息
            Write-Host "`nDNS 解析:" -ForegroundColor Gray
            $resolved = Resolve-DnsName -Name $Target -Type A -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($resolved) {
                Write-Host "  $($resolved.Name) -> $($resolved.AddressString)" -ForegroundColor Gray
            } else {
                Write-Host "  DNS 解析失败" -ForegroundColor Yellow
            }
            
            # 测试网络连通性
            Write-Host "`n网络测试:" -ForegroundColor Gray
            $pingResult = Test-NetConnection -ComputerName $Target -Port 80 -InformationLevel Detailed
            if ($pingResult) {
                Write-Host "✓ 目标地址：$($pingResult.RemoteAddress)" -ForegroundColor Green
                Write-Host "  状态：$($pingResult.Status)" -ForegroundColor Gray
                Write-Host "  往返时间：${($pingResult.RoundTripTime)}ms" -ForegroundColor Gray
                
                # 显示路由信息（如果可用）
                try {
                    $route = Get-NetRoute -DestinationPrefix $Target -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($route) {
                        Write-Host "`n路由信息:" -ForegroundColor Gray
                        Write-Host "  目标：$($route.DestinationPrefix)/$($route.PrefixLength)" -ForegroundColor Gray
                        Write-Host "  网关：$($route.NextHop)" -ForegroundColor Gray
                        Write-Host "  接口：$($route.InterfaceAlias)" -ForegroundColor Gray
                    } else {
                        Write-Host "`n未找到特定路由（使用默认网关）" -ForegroundColor Yellow
                    }
                } catch {}
            } else {
                Write-Host "✗ 无法连接到目标" -ForegroundColor Red
            }
            
        } catch {
            Write-Host "✗ 测试失败：$_" -ForegroundColor Red
        }
    }
}

if ($Command -eq "set_profile") {
    $ProfileNum = $AdapterArg
    $targetAdapter = $ThirdArg
} elseif ($Command -eq "trace_route") {
    $target = $AdapterArg
    Trace-Route -Target $target
    exit 0
} elseif ($Command -eq "set_ip") {
    if (-not $AdapterArg -or -not $ThirdArg) {
        Write-Host "Error: Usage: .\ip.ps1 set_ip <adapter> <ip_address> [mask]" -ForegroundColor Red
        exit 1
    }
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Warning: This command requires administrator privileges" -ForegroundColor Yellow
    }
    
    Set-StaticIP -Adapter $AdapterArg -IPAddress $ThirdArg -Mask $FourthArg
    exit 0
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
        
        # 直接使用 Get-NetAdapter 的 Description（更可靠）
        $description = $adapter.Description
        # 如果为空，尝试通过 WMI 查询（使用 InterfaceAlias 匹配）
        if (-not $description) {
            $wmiDesc = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.NetConnectionID -eq $alias } | Select-Object -First 1
            if ($wmiDesc) {
                $description = $wmiDesc.Description
            }
        }
        
        $ipConfig = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dns = Get-DnsClientServerAddress -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $ipInterface = Get-NetIPInterface -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dhcp = $ipInterface.Dhcp
        
        # 获取 MAC 地址
        $macAddress = $adapter.MacAddress
        
        # 获取 IPv4 默认网关
        $gateway = Get-NetRoute -InterfaceAlias $alias -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Select-Object -First 1

        $isApipa = $ipConfig -and $ipConfig.IPAddress -like "169.254.*.*"
        $hasValidIp = $ipConfig -and -not $isApipa
        
        # 第一行：适配器名 + 状态（用颜色区分）
        Write-Host ""
        Write-Host "[$alias]" -NoNewline
        $statusColor = if ($linkStatus -eq "up") { "Green" } else { "Red" }
        Write-Host " $adminStatus, $linkStatus, $linkSpeed" -ForegroundColor $statusColor
        
        # 第二行：描述信息
        if ($description) {
            Write-Host "  ($description)" -ForegroundColor Gray
        }
        
        # 第三行：MAC 地址（清理格式）
        if ($macAddress) {
            $cleanMac = $macAddress -replace '--', '-' -replace '-+', '-'
            Write-Host "     MAC: $cleanMac" -ForegroundColor Gray
        }
        
        # 第四行：IPv4 地址 + 状态（合并到一行）
        if ($ipConfig) {
            $ipStatus = if ($hasValidIp) { "" } elseif ($isApipa) { "   (APIPA, no DHCP)" } else { "   (no DHCP)" }
            $ipColor = if ($hasValidIp) { "Cyan" } elseif ($isApipa) { "Yellow" } else { "Gray" }
            Write-Host "     IPv4: $($ipConfig.IPAddress)/$($ipConfig.PrefixLength)$ipStatus" -ForegroundColor $ipColor
            

        } else {
            Write-Host "     IPv4: (none)" -ForegroundColor Gray

        }
        # 根据 IP 状态显示 DHCP（APIPA 表示 DHCP 失败）
        if ($isApipa) {
            Write-Host "     DHCP: failed to APIPA" -ForegroundColor Yellow
        } elseif (-not $dhcp -or $dhcp -eq "Disabled") {
            Write-Host "     DHCP: Disabled" -ForegroundColor Gray
        } else {
            Write-Host "     DHCP: Enabled" -ForegroundColor Green
        }

        # 第五行：Gateway（如果有）
        if ($gateway -and $gateway.NextHop -ne "0.0.0.0") {
            Write-Host "     Gateway: $($gateway.NextHop)" -ForegroundColor Green
        }
        
        # 第七行：DNS（如果有）
        if ($dns.ServerAddresses -and $dns.ServerAddresses[0] -ne "0.0.0.0") {
            Write-Host "     DNS:  $($dns.ServerAddresses -join ', ')" -ForegroundColor Green
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

function Convert-SubnetMaskToPrefixLength {
    param([string]$Mask)
    
    # If already a number (prefix length), return it
    if ($Mask -match '^\d+$') {
        return [int]$Mask
    }
    
    # Convert subnet mask to prefix length
    $octets = $Mask.Split('.')
    if ($octets.Count -ne 4) {
        return 32  # Default to /32 if invalid
    }
    
    $binary = ($octets | ForEach-Object { [Convert]::ToString($_, 2).PadLeft(8, '0') }) -join ''
    $prefixLength = ($binary.ToCharArray() | Where-Object { $_ -eq '1' }).Count
    return $prefixLength
}

function Add-StaticRoute {
    param(
        [string]$Destination,
        [string]$Mask = "255.255.255.255",
        [string]$Gateway,
        [string]$InterfaceName,
        [int]$InterfaceIndex
    )
    
    if (-not $Gateway) {
        $gateway = (Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Sort-Object -Property RouteMetric | Select-Object -First 1).NextHop
        if (-not $gateway) {
            Write-Host "Error: No default gateway found" -ForegroundColor Red
            return $false
        }
        $Gateway = $gateway
    }
    
    # Convert subnet mask to prefix length
    $prefixLength = Convert-SubnetMaskToPrefixLength -Mask $Mask
    $destinationPrefix = "$Destination/$prefixLength"
    
    # Resolve interface: -InterfaceName takes priority, then -InterfaceIndex, then auto-detect
    $ifIndex = 0
    if ($InterfaceName) {
        # User specified interface by name (e.g., "eth0", "Ethernet")
        $adapter = Get-NetAdapter -Name $InterfaceName -ErrorAction SilentlyContinue
        if (-not $adapter) {
            # Try matching by InterfaceAlias or InterfaceDescription
            $adapter = Get-NetAdapter | Where-Object { $_.InterfaceAlias -eq $InterfaceName -or $_.InterfaceDescription -like "*$InterfaceName*" } | Select-Object -First 1
        }
        if (-not $adapter) {
            Write-Host "Error: Interface '$InterfaceName' not found" -ForegroundColor Red
            Write-Host "Available interfaces:" -ForegroundColor Yellow
            Get-NetAdapter | Format-Table Name, InterfaceDescription, Status -AutoSize
            return $false
        }
        $ifIndex = $adapter.ifIndex
        Write-Host "Using interface: [$($adapter.Name)] (ifIndex $ifIndex)" -ForegroundColor Green
    } elseif ($InterfaceIndex) {
        $ifIndex = $InterfaceIndex
    } else {
        # Auto-detect: find which interface can reach the gateway
        # Try to find the route to the gateway first
        $gatewayRoute = Get-NetRoute -DestinationPrefix "$Gateway/32" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $gatewayRoute) {
            # Try finding by network: check which interface's subnet contains the gateway
            $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -ne "127.0.0.1" }
            foreach ($adapter in $adapters) {
                $adapterIP = $adapter.IPAddress
                $prefix = $adapter.PrefixLength
                # Get the network address for this adapter's subnet
                $adapterIfIndex = $adapter.InterfaceIndex
                # Check if gateway is in the same subnet as this adapter
                $routeCheck = Get-NetRoute -InterfaceIndex $adapterIfIndex -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -eq $Gateway }
                if ($routeCheck) {
                    $ifIndex = $adapterIfIndex
                    $ifAlias = (Get-NetAdapter -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue).Name
                    Write-Host "Auto-detected interface: [$ifAlias] (ifIndex $ifIndex)" -ForegroundColor Green
                    break
                }
            }
            if (-not $ifIndex) {
                # Fallback: find which interface has an IP in the same subnet as the gateway
                foreach ($adapter in $adapters) {
                    $adapterIP = $adapter.IPAddress
                    $prefix = $adapter.PrefixLength
                    # Parse IP and gateway to check if same subnet
                    $adapterBytes = [System.Net.IPAddress]::Parse($adapterIP).GetAddressBytes()
                    $gatewayBytes = [System.Net.IPAddress]::Parse($Gateway).GetAddressBytes()
                    $maskBytes = ([math]::Pow(2, $prefix) - 1)
                    # Simple check: same first 3 octets for /24
                    if ($prefix -le 24) {
                        if ($adapterIP.Split('.')[0..2] -join '.' -eq $Gateway.Split('.')[0..2] -join '.') {
                            $ifIndex = $adapter.InterfaceIndex
                            $ifAlias = (Get-NetAdapter -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue).Name
                            Write-Host "Auto-detected interface: [$ifAlias] (ifIndex $ifIndex)" -ForegroundColor Green
                            break
                        }
                    }
                }
            }
        } else {
            $ifIndex = $gatewayRoute.InterfaceIndex
            $ifAlias = (Get-NetAdapter -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue).Name
            Write-Host "Auto-detected interface: [$ifAlias] (ifIndex $ifIndex)" -ForegroundColor Green
        }
        if (-not $ifIndex) {
            Write-Host "Warning: Could not auto-detect interface for gateway $Gateway" -ForegroundColor Yellow
            Write-Host "Available interfaces:" -ForegroundColor Yellow
            Get-NetAdapter | Format-Table Name, InterfaceDescription, Status -AutoSize
        }
    }
    
    Write-Host "Adding route: $destinationPrefix via $Gateway" -ForegroundColor Cyan
    try {
        # Check if route already exists
        $existingRoute = Get-NetRoute -DestinationPrefix $destinationPrefix -ErrorAction SilentlyContinue
        if ($existingRoute) {
            Write-Host "Route already exists, removing old route..." -ForegroundColor Yellow
            Remove-NetRoute -DestinationPrefix $destinationPrefix -Confirm:$false -ErrorAction Stop
            Start-Sleep -Milliseconds 500
        }
        
        if ($ifIndex) {
            New-NetRoute -DestinationPrefix $destinationPrefix -NextHop $Gateway -InterfaceIndex $ifIndex -RouteMetric 10 -ErrorAction Stop
        } else {
            New-NetRoute -DestinationPrefix $destinationPrefix -NextHop $Gateway -RouteMetric 10 -ErrorAction Stop
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
    
    # Convert bare IP to CIDR format (/32 if no prefix specified)
    $destinationPrefix = if ($Destination -match '/') { $Destination } else { "$Destination/32" }
    
    Write-Host "Removing route: $destinationPrefix" -ForegroundColor Cyan
    try {
        $route = Get-NetRoute -DestinationPrefix $destinationPrefix -ErrorAction SilentlyContinue
        if ($route) {
            Remove-NetRoute -DestinationPrefix $destinationPrefix -Confirm:$false -ErrorAction Stop
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
        Write-Host "Error: Usage: .\ip.ps1 route_add <destination> [gateway] [-dev <interface>]" -ForegroundColor Red
        exit 1
    }
    
    $destination = $AdapterArg
    $gateway = $ThirdArg
    
    if (Add-StaticRoute -Destination $destination -Gateway $gateway -InterfaceName $DevInterface) {
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

# Helper: run sudo command via SSH, with or without password
function Invoke-SshSudo {
    param(
        [string]$TargetServer,
        [string]$Command,
        [string]$SudoPassword = ""
    )

    if ($SudoPassword) {
        # Use sudo -S to read password from stdin, -p '' to suppress prompt
        "$SudoPassword`n" | ssh $TargetServer "sudo -S -p '' $Command" 2>&1
    } else {
        ssh $TargetServer "sudo -n $Command" 2>&1
    }
}

# Helper: check sudo access, prompt for password if needed
function Test-SudoAccess {
    param([string]$TargetServer)

    # Try passwordless sudo first
    $sudoTest = ssh $TargetServer "sudo -n true 2>&1 && echo SUDO_OK || echo SUDO_FAIL" 2>&1
    if ("$sudoTest" -match "SUDO_OK") {
        Write-Host "  Sudo access OK (passwordless)" -ForegroundColor Green
        return @{ Ok = $true; Password = "" }
    }

    # Passwordless failed, prompt for password
    Write-Host "  Passwordless sudo not available." -ForegroundColor Yellow
    $securePassword = Read-Host "  Enter sudo password for ${TargetServer}" -AsSecureString
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )

    # Verify password works
    $verifyTest = "$plainPassword`n" | ssh $TargetServer "sudo -S -p '' true 2>/dev/null && echo SUDO_OK || echo SUDO_FAIL" 2>&1
    if ("$verifyTest" -notmatch "SUDO_OK") {
        Write-Host "  Error: Sudo password verification failed" -ForegroundColor Red
        return @{ Ok = $false; Password = "" }
    }
    Write-Host "  Sudo password verified" -ForegroundColor Green
    return @{ Ok = $true; Password = $plainPassword }
}

function Enable-NAT {
    param(
        [string]$TargetServer,
        [string]$Destination = "",
        [switch]$Persist
    )

    Write-Host "`n=== Enabling NAT on $TargetServer ===" -ForegroundColor Magenta

    # Check if SSH is available
    $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshCmd) {
        Write-Host "Error: SSH client not found. Install OpenSSH client." -ForegroundColor Red
        return $false
    }

    # Step 1: Test SSH connection
    Write-Host "`n[1/6] Testing SSH connection to $TargetServer..." -ForegroundColor Cyan
    $testResult = ssh -o ConnectTimeout=5 -o BatchMode=yes $TargetServer "echo OK" 2>&1
    if ($LASTEXITCODE -ne 0 -or "$testResult".Trim() -ne "OK") {
        Write-Host "  Cannot connect via SSH (requires key-based auth)" -ForegroundColor Red
        Write-Host "  Try: enable_nat user@$TargetServer -d <dest>" -ForegroundColor Yellow
        return $false
    }
    Write-Host "  SSH connection OK" -ForegroundColor Green

    # Check sudo access (prompt for password if needed)
    $sudoInfo = Test-SudoAccess -TargetServer $TargetServer
    if (-not $sudoInfo.Ok) {
        return $false
    }
    $sudoPassword = $sudoInfo.Password

    # Step 2: Enable IP forwarding
    Write-Host "`n[2/6] Enabling IP forwarding..." -ForegroundColor Cyan
    Invoke-SshSudo -TargetServer $TargetServer -Command "sysctl -w net.ipv4.ip_forward=1" -SudoPassword $sudoPassword | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    if ($Persist) {
        Invoke-SshSudo -TargetServer $TargetServer -Command "bash -c ""echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-ipforward.conf""" -SudoPassword $sudoPassword | Out-Null
    }
    $forwardStatus = (ssh $TargetServer "cat /proc/sys/net/ipv4/ip_forward" 2>&1).Trim()
    if ($forwardStatus -ne "1") {
        Write-Host "  Failed to enable IP forwarding" -ForegroundColor Red
        return $false
    }
    Write-Host "  IP forwarding enabled" -ForegroundColor Green

    # Step 3: Find inbound interface (facing local machine via SSH session)
    Write-Host "`n[3/6] Detecting inbound interface..." -ForegroundColor Cyan
    $sshClient = ssh $TargetServer 'echo $SSH_CLIENT' 2>&1
    $clientIP = ($sshClient -split ' ')[0]
    if (-not $clientIP) {
        Write-Host "  Cannot determine local IP from SSH session" -ForegroundColor Red
        return $false
    }
    Write-Host "  Local IP (from SSH): $clientIP" -ForegroundColor Gray

    $routeIn = ssh $TargetServer "ip route get $clientIP" 2>&1
    $inInterface = ([regex]::Match("$routeIn", 'dev\s+(\S+)')).Groups[1].Value
    if (-not $inInterface) {
        Write-Host "  Cannot determine inbound interface" -ForegroundColor Red
        Write-Host "  Route info: $routeIn" -ForegroundColor Gray
        return $false
    }
    Write-Host "  Inbound interface: $inInterface" -ForegroundColor Green

    # Step 4: Find outbound interface (can reach destination)
    if ($Destination) {
        Write-Host "`n[4/6] Finding outbound interface to $Destination..." -ForegroundColor Cyan
        $routeOut = ssh $TargetServer "ip route get $Destination" 2>&1
        $outInterface = ([regex]::Match("$routeOut", 'dev\s+(\S+)')).Groups[1].Value
        if (-not $outInterface) {
            Write-Host "  Cannot reach $Destination from $TargetServer" -ForegroundColor Red
            Write-Host "  Route info: $routeOut" -ForegroundColor Gray
            return $false
        }
        Write-Host "  Outbound interface: $outInterface" -ForegroundColor Green
    } else {
        Write-Host "`n[4/6] No destination specified, using default route..." -ForegroundColor Cyan
        $defaultRoute = ssh $TargetServer "ip route show default" 2>&1
        $outInterface = ([regex]::Match("$defaultRoute", 'dev\s+(\S+)')).Groups[1].Value
        if (-not $outInterface) {
            Write-Host "  No default route found" -ForegroundColor Red
            return $false
        }
        Write-Host "  Outbound interface (default): $outInterface" -ForegroundColor Green
    }

    if ($inInterface -eq $outInterface) {
        Write-Host "  Warning: inbound and outbound are the same ($inInterface)" -ForegroundColor Yellow
    }

    # Step 5: Configure iptables NAT rules
    Write-Host "`n[5/6] Configuring iptables rules..." -ForegroundColor Cyan
    Write-Host "  MASQUERADE on $outInterface" -ForegroundColor Gray
    Write-Host "  FORWARD: $inInterface <-> $outInterface" -ForegroundColor Gray

    # Clean up existing rules to avoid duplicates
    Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -t nat -D POSTROUTING -o $outInterface -j MASQUERADE 2>/dev/null; iptables -D FORWARD -i $inInterface -o $outInterface -j ACCEPT 2>/dev/null; iptables -D FORWARD -i $outInterface -o $inInterface -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; true" -SudoPassword $sudoPassword | Out-Null

    # Add rules
    $r1 = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -t nat -A POSTROUTING -o $outInterface -j MASQUERADE && echo OK" -SudoPassword $sudoPassword
    $r2 = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -A FORWARD -i $inInterface -o $outInterface -j ACCEPT && echo OK" -SudoPassword $sudoPassword
    $r3 = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -A FORWARD -i $outInterface -o $inInterface -m state --state RELATED,ESTABLISHED -j ACCEPT && echo OK" -SudoPassword $sudoPassword

    if ("$r1".Trim() -ne "OK" -or "$r2".Trim() -ne "OK" -or "$r3".Trim() -ne "OK") {
        Write-Host "  Some iptables rules failed" -ForegroundColor Red
        Write-Host "  R1: $r1" -ForegroundColor Gray
        Write-Host "  R2: $r2" -ForegroundColor Gray
        Write-Host "  R3: $r3" -ForegroundColor Gray
        return $false
    }
    Write-Host "  iptables rules configured" -ForegroundColor Green

    # Step 6: Persist if requested
    if ($Persist) {
        Write-Host "`n[6/6] Persisting rules..." -ForegroundColor Cyan
        $pkgCheck = ssh $TargetServer "dpkg -l iptables-persistent 2>/dev/null | grep -q '^ii' && echo INSTALLED || echo NOT_INSTALLED" 2>&1
        if ("$pkgCheck".Trim() -eq "NOT_INSTALLED") {
            Write-Host "  Installing iptables-persistent..." -ForegroundColor Gray
            Invoke-SshSudo -TargetServer $TargetServer -Command "DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent" -SudoPassword $sudoPassword | Out-Null
        }
        Invoke-SshSudo -TargetServer $TargetServer -Command "netfilter-persistent save" -SudoPassword $sudoPassword | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host "  Rules saved persistently" -ForegroundColor Green
    } else {
        Write-Host "`n[6/6] Skipping persistence (use -Persist to save)" -ForegroundColor Gray
    }

    # Summary
    Write-Host "`n=== NAT Configuration Summary ===" -ForegroundColor Magenta
    Write-Host "  Server:         $TargetServer" -ForegroundColor White
    Write-Host "  IP Forward:     enabled" -ForegroundColor White
    Write-Host "  Inbound (in):   $inInterface" -ForegroundColor White
    Write-Host "  Outbound (out): $outInterface" -ForegroundColor White
    if ($Destination) { Write-Host "  Destination:    $Destination" -ForegroundColor White }
    Write-Host "  Persisted:      $(if ($Persist) { 'yes' } else { 'no' })" -ForegroundColor White
    Write-Host ""
    Write-Host "  Traffic flow: Local -> $TargetServer ($inInterface -> $outInterface) -> $Destination" -ForegroundColor Cyan

    return $true
}

function Disable-NAT {
    param(
        [string]$TargetServer,
        [string]$Destination = "",
        [switch]$Persist
    )

    Write-Host "`n=== Disabling NAT on $TargetServer ===" -ForegroundColor Magenta

    # Check if SSH is available
    $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshCmd) {
        Write-Host "Error: SSH client not found. Install OpenSSH client." -ForegroundColor Red
        return $false
    }

    # Step 1: Test SSH connection
    Write-Host "`n[1/5] Testing SSH connection to $TargetServer..." -ForegroundColor Cyan
    $testResult = ssh -o ConnectTimeout=5 -o BatchMode=yes $TargetServer "echo OK" 2>&1
    if ($LASTEXITCODE -ne 0 -or "$testResult".Trim() -ne "OK") {
        Write-Host "  Cannot connect via SSH (requires key-based auth)" -ForegroundColor Red
        return $false
    }
    Write-Host "  SSH connection OK" -ForegroundColor Green

    # Check sudo access (prompt for password if needed)
    $sudoInfo = Test-SudoAccess -TargetServer $TargetServer
    if (-not $sudoInfo.Ok) {
        return $false
    }
    $sudoPassword = $sudoInfo.Password

    # Step 2: Detect interfaces (same logic as enable_nat)
    Write-Host "`n[2/5] Detecting interfaces..." -ForegroundColor Cyan
    $sshClient = ssh $TargetServer 'echo $SSH_CLIENT' 2>&1
    $clientIP = ($sshClient -split ' ')[0]
    if (-not $clientIP) {
        Write-Host "  Cannot determine local IP from SSH session" -ForegroundColor Red
        return $false
    }
    Write-Host "  Local IP (from SSH): $clientIP" -ForegroundColor Gray

    $routeIn = ssh $TargetServer "ip route get $clientIP" 2>&1
    $inInterface = ([regex]::Match("$routeIn", 'dev\s+(\S+)')).Groups[1].Value
    if (-not $inInterface) {
        Write-Host "  Cannot determine inbound interface" -ForegroundColor Red
        return $false
    }
    Write-Host "  Inbound interface: $inInterface" -ForegroundColor Green

    if ($Destination) {
        $routeOut = ssh $TargetServer "ip route get $Destination" 2>&1
        $outInterface = ([regex]::Match("$routeOut", 'dev\s+(\S+)')).Groups[1].Value
        if (-not $outInterface) {
            Write-Host "  Cannot determine outbound interface to $Destination" -ForegroundColor Red
            return $false
        }
    } else {
        $defaultRoute = ssh $TargetServer "ip route show default" 2>&1
        $outInterface = ([regex]::Match("$defaultRoute", 'dev\s+(\S+)')).Groups[1].Value
        if (-not $outInterface) {
            Write-Host "  No default route found" -ForegroundColor Red
            return $false
        }
    }
    Write-Host "  Outbound interface: $outInterface" -ForegroundColor Green

    # Step 3: Remove iptables rules
    Write-Host "`n[3/5] Removing iptables rules..." -ForegroundColor Cyan
    Write-Host "  Removing MASQUERADE on $outInterface" -ForegroundColor Gray
    Write-Host "  Removing FORWARD: $inInterface <-> $outInterface" -ForegroundColor Gray

    # Delete rules (distinguish between "not found" and "sudo failed")
    $r1 = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -t nat -D POSTROUTING -o $outInterface -j MASQUERADE 2>&1 && echo OK || echo FAILED" -SudoPassword $sudoPassword
    $r2 = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -D FORWARD -i $inInterface -o $outInterface -j ACCEPT 2>&1 && echo OK || echo FAILED" -SudoPassword $sudoPassword
    $r3 = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -D FORWARD -i $outInterface -o $inInterface -m state --state RELATED,ESTABLISHED -j ACCEPT 2>&1 && echo OK || echo FAILED" -SudoPassword $sudoPassword

    # Check results: "OK" = removed, "does not exist" / "Bad rule" = not found, "sudo" = sudo error
    function Get-IptablesResult($r) {
        $r = "$r".Trim()
        if ($r -match "OK$") { return "removed" }
        if ($r -match "(does not exist|Bad rule|No chain)") { return "not found" }
        if ($r -match "sudo|password") { return "sudo error" }
        return "failed: $r"
    }
    $c1 = Get-IptablesResult $r1
    $c2 = Get-IptablesResult $r2
    $c3 = Get-IptablesResult $r3
    $col = if ($c1 -eq "removed") { "Green" } elseif ($c1 -eq "not found") { "Gray" } else { "Red" }
    Write-Host "  MASQUERADE:            $c1" -ForegroundColor $col
    $col = if ($c2 -eq "removed") { "Green" } elseif ($c2 -eq "not found") { "Gray" } else { "Red" }
    Write-Host "  FORWARD (in->out):    $c2" -ForegroundColor $col
    $col = if ($c3 -eq "removed") { "Green" } elseif ($c3 -eq "not found") { "Gray" } else { "Red" }
    Write-Host "  FORWARD (out->in):    $c3" -ForegroundColor $col

    # Step 4: Disable IP forwarding
    Write-Host "`n[4/5] Disabling IP forwarding..." -ForegroundColor Cyan
    Invoke-SshSudo -TargetServer $TargetServer -Command "sysctl -w net.ipv4.ip_forward=0" -SudoPassword $sudoPassword | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    if ($Persist) {
        Invoke-SshSudo -TargetServer $TargetServer -Command "rm -f /etc/sysctl.d/99-ipforward.conf" -SudoPassword $sudoPassword | Out-Null
    }
    $forwardStatus = (ssh $TargetServer "cat /proc/sys/net/ipv4/ip_forward" 2>&1).Trim()
    if ($forwardStatus -eq "0") {
        Write-Host "  IP forwarding disabled" -ForegroundColor Green
    } else {
        Write-Host "  IP forwarding still enabled (value: $forwardStatus)" -ForegroundColor Yellow
    }

    # Step 5: Persist if requested
    if ($Persist) {
        Write-Host "`n[5/5] Persisting changes..." -ForegroundColor Cyan
        $pkgCheck = ssh $TargetServer "dpkg -l iptables-persistent 2>/dev/null | grep -q '^ii' && echo INSTALLED || echo NOT_INSTALLED" 2>&1
        if ("$pkgCheck".Trim() -eq "INSTALLED") {
            Invoke-SshSudo -TargetServer $TargetServer -Command "netfilter-persistent save" -SudoPassword $sudoPassword | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            Write-Host "  Rules saved persistently" -ForegroundColor Green
        } else {
            Write-Host "  iptables-persistent not installed, nothing to persist" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n[5/5] Skipping persistence (use -Persist to save)" -ForegroundColor Gray
    }

    # Summary
    Write-Host "`n=== NAT Disabled Summary ===" -ForegroundColor Magenta
    Write-Host "  Server:         $TargetServer" -ForegroundColor White
    Write-Host "  Inbound (in):   $inInterface" -ForegroundColor White
    Write-Host "  Outbound (out): $outInterface" -ForegroundColor White
    Write-Host "  IP Forward:     $forwardStatus" -ForegroundColor White
    Write-Host "  Persisted:      $(if ($Persist) { 'yes' } else { 'no' })" -ForegroundColor White
    Write-Host ""
    Write-Host "  NAT removed. Traffic to $Destination will no longer be forwarded." -ForegroundColor Cyan

    return $true
}

# === Command handlers (must be after all function definitions) ===

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

if ($Command -eq "enable_nat") {
    if (-not $AdapterArg) {
        Write-Host "Error: Usage: .\ip.ps1 enable_nat <target_server> [-d <destination>] [-Persist]" -ForegroundColor Red
        Write-Host "  target_server: SSH target (e.g., 192.168.137.2 or user@192.168.137.2)" -ForegroundColor Yellow
        Write-Host "  -d <dest>:     Destination IP to route through (e.g., 172.17.1.122)" -ForegroundColor Yellow
        Write-Host "  -Persist:      Save rules across reboot" -ForegroundColor Yellow
        Write-Host "  -p 1:          Alternative for -Persist" -ForegroundColor Yellow
        exit 1
    }

    $targetServer = $AdapterArg
    $destination = $NatDest
    $shouldPersist = $Persist -or (-not [string]::IsNullOrWhiteSpace($ProfileNum))

    if (Enable-NAT -TargetServer $targetServer -Destination $destination -Persist:$shouldPersist) {
        Write-Host "`nDone!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to enable NAT" -ForegroundColor Red
        exit 1
    }
    exit 0
}

if ($Command -eq "disable_nat") {
    if (-not $AdapterArg) {
        Write-Host "Error: Usage: .\ip.ps1 disable_nat <target_server> [-d <destination>] [-Persist]" -ForegroundColor Red
        Write-Host "  target_server: SSH target (e.g., 192.168.137.2 or user@192.168.137.2)" -ForegroundColor Yellow
        Write-Host "  -d <dest>:     Destination IP (should match enable_nat -d)" -ForegroundColor Yellow
        Write-Host "  -Persist:      Save cleared rules across reboot" -ForegroundColor Yellow
        Write-Host "  -p 1:          Alternative for -Persist" -ForegroundColor Yellow
        exit 1
    }

    $targetServer = $AdapterArg
    $destination = $NatDest
    $shouldPersist = $Persist -or (-not [string]::IsNullOrWhiteSpace($ProfileNum))

    if (Disable-NAT -TargetServer $targetServer -Destination $destination -Persist:$shouldPersist) {
        Write-Host "`nDone!" -ForegroundColor Green
    } else {
        Write-Host "`nFailed to disable NAT" -ForegroundColor Red
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
    Write-Host "  .\ip.ps1 route_add <dest> [gateway] [-dev <if>]   Add static route (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 route_del <dest>             Delete route (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_profile <1|2|3> [adapter] Apply network profile" -ForegroundColor White
    Write-Host "  .\ip.ps1 trace_route <target>         Trace route to target" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_ip <adapter> <ip> [mask] Set static IP freely (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 enable_nat <server> [-d <dest>] [-Persist]  Enable NAT on remote Linux (via SSH)" -ForegroundColor White
    Write-Host "  .\ip.ps1 disable_nat <server> [-d <dest>] [-Persist] Disable NAT on remote Linux (via SSH)" -ForegroundColor White
    Write-Host ""
    Write-Host "Profiles:" -ForegroundColor Cyan
    Write-Host "  Profile 1: Static IP (192.168.137.1/24, DHCP DNS)" -ForegroundColor Gray
    Write-Host "  Profile 2: DHCP + Custom DNS (176.16.98.100)" -ForegroundColor Gray
    Write-Host "  Profile 3: Static IP (192.168.50.11/24) with Gateway (192.168.50.1)" -ForegroundColor Gray
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

} elseif ($profile -eq "3") {
    $targetIp = "192.168.50.11"
    $gateway = "192.168.50.1"
    Write-Host "Profile 3: Setting [$targetAdapter] to static IP: $targetIp/24 with Gateway: $gateway ..." -ForegroundColor Cyan

    if (-not (Clear-IPConflict -ipToCheck $targetIp -newIp "192.168.50.11")) {
        Write-Host "  Warning: IP conflict detected" -ForegroundColor Yellow
    }

    Write-Host "  Setting [$targetAdapter] IP to static $targetIp/24 ..." -ForegroundColor Gray
    $result = netsh interface ip set address name=$targetAdapter static $targetIp 255.255.255.0 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed: $result" -ForegroundColor Red
        $hasError = $true
    }

    Write-Host "  Setting [$targetAdapter] Gateway to $gateway ..." -ForegroundColor Gray
    netsh interface ip set route name=$targetAdapter gateway=$gateway persist 2>&1 | Out-Null
} else {
    Write-Host "Unknown profile: $profile" -ForegroundColor Red
    Write-Host "Usage: .\ip.ps1 -p <1|2|3> [adapter]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Profile 1: Static IP (192.168.137.1/24)" -ForegroundColor Gray
    Write-Host "  Profile 2: DHCP + Custom DNS (176.16.98.100)" -ForegroundColor Gray
    Write-Host "  Profile 3: Static IP (192.168.50.11/24) with Gateway (192.168.50.1)" -ForegroundColor Gray
    exit 1
}

if (-not $hasError) {
    Write-Host "`nDone!" -ForegroundColor Green
} else {
    Write-Host "`nSome operations failed" -ForegroundColor Red
    exit 1
}






