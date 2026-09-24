param(
    [Parameter(Position=0)][string]$Command,
    [Parameter(Position=1)][string]$AdapterArg,
    [Parameter(Position=2)][string]$ThirdArg,
    [Parameter(Position=3)][string]$FourthArg,
    [Parameter()][Alias("p")][string]$ProfileNum,
    [Parameter()][Alias("d")][string]$NatDest,
    [Parameter()][Alias("h")][switch]$Human,
    [Parameter()][switch]$Persist,
    [Parameter()][Alias("dev")][string]$DevInterface
)

# === 版本信息（功能变更时手动更新 $ScriptVersion；时间戳/commit 运行时自动读取） ===
$ScriptVersion = "1.3.2"

function Show-Version {
    $editTime = (Get-Item $PSCommandPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "`n=== ip.ps1 Version Info ===" -ForegroundColor Magenta
    Write-Host "  Version: $ScriptVersion" -ForegroundColor Cyan
    Write-Host "  Edited:  $editTime" -ForegroundColor White

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $commit = git -C $PSScriptRoot log -1 --format="%h %ci %s" 2>$null
        if ($LASTEXITCODE -eq 0 -and $commit) {
            Write-Host "  Commit:  $commit" -ForegroundColor White
        } else {
            Write-Host "  Commit:  (not a git repository)" -ForegroundColor Gray
        }
        $remote = git -C $PSScriptRoot remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $remote) {
            Write-Host "  Repo:    $remote" -ForegroundColor White
        }
    } else {
        Write-Host "  Commit:  (git not available)" -ForegroundColor Gray
    }
}

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
} elseif ($Command -eq "version" -or $Command -eq "-v" -or $Command -eq "--version") {
    Show-Version
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

# Select the outbound interface for a NAT destination by actually testing reachability.
# -Auto: iterate candidates (NM-route-backed first, then on-link probe); none reachable -> cleanup + fail.
# otherwise: interactive numbered picker; q aborts with cleanup.
# Returns @{ Ok; Iface; ViaGw } (ViaGw empty = on-link success).
function Select-NatOutboundInterface {
    param(
        [string]$TargetServer,
        [string]$Destination,
        [switch]$Auto,
        [string]$SudoPassword,
        [string]$InboundInterface
    )

    # Candidate interfaces: exclude loopback, docker/bridge/veth plumbing and the inbound NIC
    $ifaceRaw = ssh $TargetServer "ls /sys/class/net" 2>&1
    $candidates = @(@(($ifaceRaw -split '\s+') | Where-Object { $_ }) | Where-Object {
        $_ -ne "lo" -and $_ -ne $InboundInterface -and $_ -notmatch "^(docker|veth|br-|virbr|wg|tailscale)"
    })

    # Enrich each candidate with its NM connection name and next-hop from existing ipv4.routes
    $nmConns = ssh $TargetServer "nmcli -t -f NAME,DEVICE con show --active" 2>&1
    $info = @()
    foreach ($cand in $candidates) {
        $connName = ""
        if ("$nmConns" -notmatch "not found") {
            foreach ($line in @($nmConns)) {
                if ("$line" -match "^(.*):$([regex]::Escape($cand))$") { $connName = $Matches[1]; break }
            }
        }
        $nh = ""
        if ($connName) {
            $routes = (ssh $TargetServer "nmcli -t -f ipv4.routes con show '$connName'" 2>&1 | Out-String).Trim()
            if ($routes -match "nh\s*=\s*(\d{1,3}(?:\.\d{1,3}){3})") { $nh = $Matches[1] }
            else {
                $ips = @([regex]::Matches("$routes", "(\d{1,3}(?:\.\d{1,3}){3})") | ForEach-Object { $_.Groups[1].Value })
                if ($ips.Count -ge 2) { $nh = $ips[1] }
            }
        }
        $info += @{ Iface = $cand; Conn = $connName; Nh = $nh }
    }
    # NM-route-backed candidates first (deterministic: Where-Object, not Sort-Object,
    # which is unstable in Windows PowerShell 5.1)
    $info = @(@($info | Where-Object { $_.Nh }) + @($info | Where-Object { -not $_.Nh }))

    if ($info.Count -eq 0) {
        Write-Host "  No candidate interfaces found on $TargetServer" -ForegroundColor Red
        return @{ Ok = $false; Iface = ""; ViaGw = "" }
    }

    # Test one candidate: with a known next-hop, install a temporary /32 route and ping;
    # without one, probe on-link reachability (ping -I). Failed routes are removed immediately.
    $testCand = {
        param($cand, $nh)
        if ($nh) {
            Invoke-SshSudo -TargetServer $TargetServer -Command "ip route replace $Destination/32 via $nh dev $cand" -SudoPassword $SudoPassword | Out-Null
            ssh $TargetServer "ping -c 2 -W 1 $Destination" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { return @{ Ok = $true; Via = $nh } }
            Invoke-SshSudo -TargetServer $TargetServer -Command "ip route del $Destination/32 dev $cand 2>/dev/null; true" -SudoPassword $SudoPassword | Out-Null
            return @{ Ok = $false }
        } else {
            ssh $TargetServer "ping -c 2 -W 1 -I $cand $Destination" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { return @{ Ok = $true; Via = "" } }
            return @{ Ok = $false }
        }
    }

    if ($Auto) {
        Write-Host "  AUTO: testing candidate interfaces for reachability to $Destination..." -ForegroundColor Cyan
        foreach ($entry in $info) {
            $hint = if ($entry.Nh) { "route via $($entry.Nh)" } else { "on-link probe" }
            Write-Host "  Testing $($entry.Iface) ($hint)..." -ForegroundColor Gray
            $res = & $testCand -cand $entry.Iface -nh $entry.Nh
            if ($res.Ok) {
                Write-Host "  AUTO selected: $($entry.Iface) ($Destination responds)" -ForegroundColor Green
                return @{ Ok = $true; Iface = $entry.Iface; ViaGw = $res.Via }
            }
        }
        # Final residue sweep: drop any /32 route left for the destination
        Invoke-SshSudo -TargetServer $TargetServer -Command "ip route del $Destination/32 2>/dev/null; true" -SudoPassword $SudoPassword | Out-Null
        Write-Host "  AUTO failed: no interface reaches $Destination (temporary routes cleaned up)" -ForegroundColor Red
        return @{ Ok = $false; Iface = ""; ViaGw = "" }
    }

    while ($true) {
        Write-Host "`n  $Destination does not respond via the kernel-selected route. Pick the outbound interface:" -ForegroundColor Yellow
        $i = 1
        foreach ($entry in $info) {
            $hint = if ($entry.Conn) { "NM '$($entry.Conn)'" } else { "no NM connection" }
            if ($entry.Nh) { $hint += ", existing route via $($entry.Nh)" }
            Write-Host "    $i. $($entry.Iface)  ($hint)" -ForegroundColor White
            $i++
        }
        $choice = Read-Host "  Enter number (q=abort)"
        if ("$choice" -match '^q$') {
            Invoke-SshSudo -TargetServer $TargetServer -Command "ip route del $Destination/32 2>/dev/null; true" -SudoPassword $SudoPassword | Out-Null
            return @{ Ok = $false; Iface = ""; ViaGw = "" }
        }
        $idx = 0
        if ([int]::TryParse("$choice", [ref]$idx) -and $idx -ge 1 -and $idx -le $info.Count) {
            $entry = $info[$idx - 1]
            Write-Host "  Testing $($entry.Iface)..." -ForegroundColor Gray
            $res = & $testCand -cand $entry.Iface -nh $entry.Nh
            if ($res.Ok) {
                Write-Host "  Selected: $($entry.Iface) ($Destination responds)" -ForegroundColor Green
                return @{ Ok = $true; Iface = $entry.Iface; ViaGw = $res.Via }
            }
            Write-Host "  $Destination does not respond via $($entry.Iface) - pick another" -ForegroundColor Red
        } else {
            Write-Host "  Invalid choice" -ForegroundColor Yellow
        }
    }
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
    $viaGw = ""
    $forcedDev = ""
    if ($DevInterface -and $DevInterface -ne "AUTO") {
        Write-Host "`n[4/6] Outbound interface forced to $DevInterface (-dev)..." -ForegroundColor Cyan
        ssh $TargetServer "ip link show $DevInterface" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Interface $DevInterface does not exist on $TargetServer" -ForegroundColor Red
            return $false
        }
        $forcedDev = $DevInterface
        $outInterface = $forcedDev
        if ($Destination) {
            $routeOut = ssh $TargetServer "ip route get $Destination" 2>&1
            $kernelDev = ([regex]::Match("$routeOut", 'dev\s+(\S+)')).Groups[1].Value
            Write-Host "  Route info: $("$routeOut".Trim())" -ForegroundColor Gray
            if ($kernelDev -and $kernelDev -ne $forcedDev) {
                Write-Host "  Warning: kernel currently routes $Destination via $kernelDev - a host route will be added to override it" -ForegroundColor Yellow
            }
        }
        Write-Host "  Outbound interface: $outInterface" -ForegroundColor Green
    } elseif ($Destination) {
        Write-Host "`n[4/6] Finding outbound interface to $Destination..." -ForegroundColor Cyan
        $routeOut = ssh $TargetServer "ip route get $Destination" 2>&1
        $outInterface = ([regex]::Match("$routeOut", 'dev\s+(\S+)')).Groups[1].Value
        if (-not $outInterface) {
            Write-Host "  Cannot reach $Destination from $TargetServer" -ForegroundColor Red
            Write-Host "  Route info: $routeOut" -ForegroundColor Gray
            return $false
        }
        $viaGw = ([regex]::Match("$routeOut", 'via\s+(\S+)')).Groups[1].Value
        Write-Host "  Outbound interface: $outInterface" -ForegroundColor Green

        # Verify the kernel-selected path actually reaches the destination
        # (kernel can route e.g. into a docker bridge where no host answers)
        ssh $TargetServer "ping -c 2 -W 1 $Destination" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Warning: $Destination does not respond via $outInterface" -ForegroundColor Yellow
            $autoMode = ($DevInterface -eq "AUTO")
            $sel = Select-NatOutboundInterface -TargetServer $TargetServer -Destination $Destination -Auto:$autoMode -SudoPassword $sudoPassword -InboundInterface $inInterface
            if (-not $sel.Ok) {
                Write-Host "  Cannot reach $Destination from any interface - aborting (temporary config cleaned)" -ForegroundColor Red
                return $false
            }
            $outInterface = $sel.Iface
            $viaGw = $sel.ViaGw
            $forcedDev = $outInterface
            $selHow = if ($autoMode) { "auto-selected" } else { "user-selected" }
            Write-Host "  Outbound interface ($selHow): $outInterface" -ForegroundColor Green
        }
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

    # Step 4b: make the destination route persistent via NetworkManager
    # (+ipv4.routes APPENDS the entry; existing routes are never touched)
    if ($Destination -and $forcedDev) {
        # Forced interface: kernel may route the destination elsewhere (e.g. docker0),
        # so reuse the next-hop from existing route entries on that connection and add
        # a /32 host route (runtime + persistent)
        Write-Host "  Ensuring route to $Destination goes via $forcedDev (runtime + NM persistent)..." -ForegroundColor Gray
        $nmConns = ssh $TargetServer "nmcli -t -f NAME,DEVICE con show --active" 2>&1
        $nmConnName = ""
        if ("$nmConns" -match "not found") {
            Write-Host "  nmcli not available - route persistence skipped" -ForegroundColor Yellow
        } else {
            foreach ($line in @($nmConns)) {
                if ("$line" -match "^(.*):$([regex]::Escape($forcedDev))$") { $nmConnName = $Matches[1]; break }
            }
            if (-not $nmConnName) {
                Write-Host "  No active NM connection on $forcedDev - route persistence skipped" -ForegroundColor Yellow
            } else {
                $nmRoutes = (ssh $TargetServer "nmcli -t -f ipv4.routes con show '$nmConnName'" 2>&1 | Out-String).Trim()
                $destPat = "(?<![\d.])" + [regex]::Escape($Destination) + "(?![\d.])"

                # Next-hop: reuse the one from existing route entries on this connection
                # (new format "nh = x.x.x.x", else old format "dest/32 x.x.x.x")
                $nh = ""
                if ($nmRoutes -match "nh\s*=\s*(\d{1,3}(?:\.\d{1,3}){3})") { $nh = $Matches[1] }
                else {
                    $routeIps = @([regex]::Matches("$nmRoutes", "(\d{1,3}(?:\.\d{1,3}){3})") | ForEach-Object { $_.Groups[1].Value })
                    if ($routeIps.Count -ge 2) { $nh = $routeIps[1] }
                }

                if ("$nmRoutes" -match $destPat) {
                    Write-Host "  NM route already present in '$nmConnName' ipv4.routes - nothing to add" -ForegroundColor Green
                } else {
                    $nhNote = if ($nh) { " (reusing next-hop $nh from existing entries)" } else { " (on-link)" }
                    Write-Host "  Adding persistent route via '$nmConnName'$nhNote..." -ForegroundColor Gray
                    # Older nmcli only accepts "ip/prefix next_hop"; newer also allows "via" - try both
                    $modTried = if ($nh) { @("$Destination/32 $nh", "$Destination/32 via $nh") } else { @("$Destination/32") }
                    $added = $false
                    $modOut = $null
                    foreach ($routeSpec in $modTried) {
                        $modOut = Invoke-SshSudo -TargetServer $TargetServer -Command "nmcli con mod '$nmConnName' +ipv4.routes '$routeSpec'" -SudoPassword $sudoPassword
                        $nmRoutesAfter = (ssh $TargetServer "nmcli -t -f ipv4.routes con show '$nmConnName'" 2>&1 | Out-String).Trim()
                        if ("$nmRoutesAfter" -match $destPat) {
                            Write-Host "  Persistent route added (+ipv4.routes '$routeSpec', existing entries preserved)" -ForegroundColor Green
                            $added = $true
                            break
                        }
                    }
                    if (-not $added) {
                        Write-Host "  Warning: failed to persist route via NM" -ForegroundColor Red
                        if ($modOut) { Write-Host "  nmcli said: $modOut" -ForegroundColor Gray }
                        Write-Host "  Add manually: nmcli con mod '$nmConnName' +ipv4.routes '$($modTried[0])'" -ForegroundColor Yellow
                    }
                }

                # Runtime host route so the forced interface takes effect immediately
                $routeNow = ssh $TargetServer "ip route get $Destination" 2>&1
                $routeNowDev = ([regex]::Match("$routeNow", 'dev\s+(\S+)')).Groups[1].Value
                if ($routeNowDev -ne $forcedDev) {
                    $rtCmd = if ($nh) { "ip route replace $Destination/32 via $nh dev $forcedDev" } else { "ip route replace $Destination/32 dev $forcedDev" }
                    Invoke-SshSudo -TargetServer $TargetServer -Command $rtCmd -SudoPassword $sudoPassword | Out-Null
                    $routeNow2 = ssh $TargetServer "ip route get $Destination" 2>&1
                    $routeNowDev2 = ([regex]::Match("$routeNow2", 'dev\s+(\S+)')).Groups[1].Value
                    if ($routeNowDev2 -eq $forcedDev) {
                        $rtNote = if ($nh) { "via $nh" } else { "on-link" }
                        Write-Host "  Runtime route active: $Destination/32 dev $forcedDev ($rtNote)" -ForegroundColor Green
                    } else {
                        Write-Host "  Warning: runtime route replace failed ($("$routeNow2".Trim()))" -ForegroundColor Red
                    }
                }
            }
        }
    } elseif ($Destination -and $viaGw) {
        Write-Host "  Checking NetworkManager route persistence for $Destination..." -ForegroundColor Gray
        $nmConns = ssh $TargetServer "nmcli -t -f NAME,DEVICE con show --active" 2>&1
        $nmConnName = ""
        if ("$nmConns" -match "not found") {
            Write-Host "  nmcli not available - route persistence skipped (runtime route still works)" -ForegroundColor Yellow
        } else {
            foreach ($line in @($nmConns)) {
                if ("$line" -match "^(.*):$([regex]::Escape($outInterface))$") { $nmConnName = $Matches[1]; break }
            }
            if (-not $nmConnName) {
                Write-Host "  No active NM connection on $outInterface - route persistence skipped" -ForegroundColor Yellow
            } else {
                $nmRoutes = (ssh $TargetServer "nmcli -t -f ipv4.routes con show '$nmConnName'" 2>&1 | Out-String).Trim()
                $destPat = "(?<![\d.])" + [regex]::Escape($Destination) + "(?![\d.])"
                if ("$nmRoutes" -match $destPat) {
                    Write-Host "  NM route already present in '$nmConnName' ipv4.routes - nothing to add" -ForegroundColor Green
                } else {
                    Invoke-SshSudo -TargetServer $TargetServer -Command "nmcli con mod '$nmConnName' +ipv4.routes '$Destination/32 via $viaGw'" -SudoPassword $sudoPassword | Out-Null
                    $nmRoutesAfter = (ssh $TargetServer "nmcli -t -f ipv4.routes con show '$nmConnName'" 2>&1 | Out-String).Trim()
                    if ("$nmRoutesAfter" -match $destPat) {
                        Write-Host "  Persistent route added: '$nmConnName' +ipv4.routes '$Destination/32 via $viaGw'" -ForegroundColor Green
                        Write-Host "  (existing ipv4.routes entries were preserved)" -ForegroundColor Gray
                    } else {
                        Write-Host "  Warning: failed to persist route via NM (runtime route still active)" -ForegroundColor Red
                    }
                }
            }
        }
    } elseif ($Destination) {
        Write-Host "  Route to $Destination is on-link via $outInterface (no gateway hop) - no NM route entry needed" -ForegroundColor Gray
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
    $viaNote = if ($viaGw) { " via $viaGw" } else { "" }
    $destPart = if ($Destination) { " -> $Destination" } else { " -> external" }
    Write-Host "  Traffic flow: local($clientIP) -> in:$inInterface -> [NAT out:$outInterface$viaNote]$destPart" -ForegroundColor Cyan

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

# Helper: extract an option value from an "iptables -S" rule line ("! -o x" / "-o !x" / "-o x" all handled)
function Get-RuleOpt {
    param([string]$Rule, [string]$Opt)

    $m = [regex]::Match($Rule, "(?:^|\s)!\s+$Opt\s+(\S+)")
    if ($m.Success) { return "!$($m.Groups[1].Value)" }
    $m = [regex]::Match($Rule, "(?:^|\s)$Opt\s+!(\S+)")
    if ($m.Success) { return "!$($m.Groups[1].Value)" }
    $m = [regex]::Match($Rule, "(?:^|\s)$Opt\s+(\S+)")
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

# Helper: return $true when a rule positively references an interface absent from the host
# (negated "!" references and "eth+" wildcards are always considered valid)
function Test-StaleIface {
    param([string]$Iface, [string[]]$Existing)

    if (-not $Iface) { return $false }
    if ($Iface.StartsWith("!")) { return $false }
    if ($Iface.EndsWith("+")) { return $false }
    if ($Existing.Count -eq 0) { return $false }
    return ($Existing -notcontains $Iface)
}

# Helper: render one "iptables -S" rule line as a compact human-readable string
function Format-IptablesRuleHuman {
    param([string]$Rule, [string[]]$ExistingIfaces = @())

    $inIf = Get-RuleOpt -Rule $Rule -Opt "-i"
    $outIf = Get-RuleOpt -Rule $Rule -Opt "-o"
    $src = Get-RuleOpt -Rule $Rule -Opt "-s"
    $dst = Get-RuleOpt -Rule $Rule -Opt "-d"
    $target = Get-RuleOpt -Rule $Rule -Opt "-j"
    $state = Get-RuleOpt -Rule $Rule -Opt "--state"

    $parts = @()
    if ($src -and $src -ne "0.0.0.0/0") { $parts += "src $src" }
    $parts += "in:$(if ($inIf) { $inIf } else { '*' })"
    $parts += "out:$(if ($outIf) { $outIf } else { '*' })"
    if ($dst -and $dst -ne "0.0.0.0/0") { $parts += "dst $dst" }
    if ($state) { $parts += "state:$state" }
    if ($target) { $parts += "-> $target" }
    $line = $parts -join " "

    if ($ExistingIfaces.Count -gt 0) {
        $stale = @()
        if (Test-StaleIface -Iface $inIf -Existing $ExistingIfaces) { $stale += $inIf }
        if (Test-StaleIface -Iface $outIf -Existing $ExistingIfaces) { $stale += $outIf }
        if ($stale.Count -gt 0) { $line += "  [stale iface: $(($stale | Sort-Object -Unique) -join ', ')]" }
    }
    return $line
}

function Show-NAT {
    param(
        [string]$TargetServer,
        [string]$Destination = "",
        [string]$DevOverride = "",
        [switch]$Human
    )

    Write-Host "`n=== NAT Status on $TargetServer ===" -ForegroundColor Magenta

    # Check if SSH is available
    $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshCmd) {
        Write-Host "Error: SSH client not found. Install OpenSSH client." -ForegroundColor Red
        return $false
    }

    # Step 1: Test SSH connection
    Write-Host "`n[1/4] Testing SSH connection to $TargetServer..." -ForegroundColor Cyan
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

    if ($Human) {
        # --- Compact human-friendly summary ---
        $forwardStatus = (ssh $TargetServer "cat /proc/sys/net/ipv4/ip_forward" 2>&1).Trim()
        $persistConf = (ssh $TargetServer "cat /etc/sysctl.d/99-ipforward.conf 2>/dev/null" 2>$null | Out-String).Trim()

        $sshClient = ssh $TargetServer 'echo $SSH_CLIENT' 2>&1
        $clientIP = ($sshClient -split ' ')[0]
        $inInterface = ""
        if ($clientIP) {
            $routeIn = ssh $TargetServer "ip route get $clientIP" 2>&1
            $inInterface = ([regex]::Match("$routeIn", 'dev\s+(\S+)')).Groups[1].Value
        }
        # Outbound interface: forced -dev, else -d route lookup, else default route
        if ($DevOverride) {
            $outInterface = $DevOverride
        } elseif ($Destination) {
            $routeOut = ssh $TargetServer "ip route get $Destination" 2>&1
            $outInterface = ([regex]::Match("$routeOut", 'dev\s+(\S+)')).Groups[1].Value
        } else {
            $defaultRoute = ssh $TargetServer "ip route show default" 2>&1
            $outInterface = ([regex]::Match("$defaultRoute", 'dev\s+(\S+)')).Groups[1].Value
        }

        $natRulesS = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -t nat -S POSTROUTING" -SudoPassword $sudoPassword
        $fwdRulesS = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -S FORWARD" -SudoPassword $sudoPassword

        # Interfaces actually present on the host (for stale-rule detection)
        $ifaceRaw = ssh $TargetServer "ls /sys/class/net" 2>&1
        $ifaceList = @()
        if ($LASTEXITCODE -eq 0) {
            $ifaceList = @(($ifaceRaw -split '\s+') | Where-Object { $_ })
        }

        $masqLines = @(@($natRulesS) | Where-Object { $_ -match "^-A POSTROUTING" -and $_ -match "MASQUERADE" })
        $allFwd = @(@($fwdRulesS) | Where-Object { $_ -match "^-A FORWARD" })
        $fwdLines = @($allFwd | Where-Object { $_ -notmatch "-j DOCKER" })
        $dockerCount = @($allFwd | Where-Object { $_ -match "-j DOCKER" }).Count

        $fwEnabled = ("$forwardStatus".Trim() -eq "1")
        $natActive = ($masqLines.Count -gt 0)

        Write-Host "`n=== NAT Summary: $TargetServer ===" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  IP forwarding:  $(if ($fwEnabled) { 'enabled' } else { 'disabled' })$(if ($persistConf) { '  (persistent: yes)' } else { '' })" -ForegroundColor $(if ($fwEnabled) { "Green" } else { "Red" })
        Write-Host "  NAT status:     $(if ($natActive) { 'ACTIVE' } else { 'INACTIVE (no MASQUERADE rule)' })" -ForegroundColor $(if ($natActive) { "Green" } else { "Red" })
        if ($inInterface) {
            Write-Host "  Inbound iface:  $inInterface $(if ($clientIP) { "(local $clientIP)" })" -ForegroundColor White
        }
        if ($outInterface) {
            $outLabel = if ($DevOverride) { "forced via -dev" } elseif ($Destination) { "route to $Destination" } else { "default route" }
            Write-Host "  Outbound iface: $outInterface ($outLabel)" -ForegroundColor White
            if ($Destination) {
                Write-Host "  Route detail:   $("$routeOut".Trim())" -ForegroundColor DarkGray
            }
        } elseif ($Destination) {
            Write-Host "  Outbound iface: (no route to $Destination)" -ForegroundColor Red
            Write-Host "  Route detail:   $("$routeOut".Trim())" -ForegroundColor DarkGray
        }

        # NetworkManager route persistence check (same place enable_nat -d writes it)
        if ($Destination -and $outInterface) {
            $nmConns = ssh $TargetServer "nmcli -t -f NAME,DEVICE con show --active" 2>&1
            $nmConnName = ""
            if ("$nmConns" -notmatch "not found") {
                foreach ($line in @($nmConns)) {
                    if ("$line" -match "^(.*):$([regex]::Escape($outInterface))$") { $nmConnName = $Matches[1]; break }
                }
            }
            if ($nmConnName) {
                $nmRoutes = (ssh $TargetServer "nmcli -t -f ipv4.routes con show '$nmConnName'" 2>&1 | Out-String).Trim()
                $destPat = "(?<![\d.])" + [regex]::Escape($Destination) + "(?![\d.])"
                if ("$nmRoutes" -match $destPat) {
                    Write-Host "  NM route persist: '$nmConnName' ipv4.routes contains $Destination" -ForegroundColor Green
                } else {
                    Write-Host "  NM route persist: $Destination NOT in '$nmConnName' ipv4.routes (route won't survive reboot; enable_nat -d will add it)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  NM route persist: no active NM connection on $outInterface (route comes from docker/manual config)" -ForegroundColor Gray
            }
        }

        # Docker bridge verification: does docker0 actually carry containers, and who owns the destination IP
        if ($ifaceList -contains "docker0") {
            $dockerPs = Invoke-SshSudo -TargetServer $TargetServer -Command "docker ps --format '{{.Names}} {{.IPAddress}}'" -SudoPassword $sudoPassword
            if ("$dockerPs" -match "Cannot connect to the Docker daemon|command not found|permission denied|Permission denied") {
                Write-Host "  Docker check:   unavailable on $TargetServer" -ForegroundColor Gray
            } else {
                $dockerLines = @(@($dockerPs) | Where-Object { "$_".Trim() })
                $withIp = @($dockerLines | Where-Object { "$_" -match "\d+\.\d+\.\d+\.\d+" })
                if ($dockerLines.Count -eq 0) {
                    Write-Host "  Docker check:   0 containers running on docker0" -ForegroundColor Yellow
                } elseif ($withIp.Count -eq 0) {
                    Write-Host "  Docker check:   $($dockerLines.Count) containers, but IPs not visible (custom networks - verify via docker inspect)" -ForegroundColor Gray
                } else {
                    Write-Host "  Docker check:   $($dockerLines.Count) containers: $($dockerLines -join '; ')" -ForegroundColor Gray
                }
                if ($Destination -and $withIp.Count -gt 0) {
                    $owner = @($dockerLines | Where-Object { "$_" -match "(?<![\d.])$([regex]::Escape($Destination))(?![\d.])" })
                    if ($owner.Count -gt 0) {
                        Write-Host "  Docker target:  $Destination is owned by $($owner -join ', ')" -ForegroundColor Green
                    } else {
                        Write-Host "  Docker target:  $Destination NOT owned by any container (traffic to it would die on the bridge)" -ForegroundColor Red
                    }
                }
            }
        }

        Write-Host "`n  NAT rules (POSTROUTING):" -ForegroundColor Yellow
        if ($natActive) {
            $i = 1
            foreach ($r in $masqLines) {
                $src = Get-RuleOpt -Rule $r -Opt "-s"
                $outIf = Get-RuleOpt -Rule $r -Opt "-o"
                if (-not $src) { $src = "any source" }
                if (Test-StaleIface -Iface $outIf -Existing $ifaceList) {
                    Write-Host "    $i. $src -> via $outIf  (MASQUERADE)  [stale iface: $outIf]" -ForegroundColor Yellow
                } else {
                    Write-Host "    $i. $src -> via $outIf  (MASQUERADE)" -ForegroundColor Gray
                }
                $i++
            }
        } else {
            Write-Host "    (none)" -ForegroundColor Red
        }

        Write-Host "`n  FORWARD rules:" -ForegroundColor Yellow
        $policy = ([regex]::Match((@($fwdRulesS) -join "`n"), '(?m)^-P FORWARD (\S+)')).Groups[1].Value
        if ($policy) {
            Write-Host "    default policy: $policy" -ForegroundColor Gray
        }
        if ($fwdLines.Count -gt 0) {
            $i = 1
            foreach ($r in $fwdLines) {
                $ruleText = Format-IptablesRuleHuman -Rule $r -ExistingIfaces $ifaceList
                if ("$ruleText" -match "\[stale iface") {
                    Write-Host "    $i. $ruleText" -ForegroundColor Yellow
                } else {
                    Write-Host "    $i. $ruleText" -ForegroundColor Gray
                }
                $i++
            }
        } else {
            Write-Host "    (none)" -ForegroundColor Red
        }
        if ($dockerCount -gt 0) {
            Write-Host "    (+ $dockerCount docker-related rules hidden)" -ForegroundColor DarkGray
        }

        # Summarize rules referencing interfaces that no longer exist
        $staleAll = @()
        foreach ($r in @($masqLines + $fwdLines)) {
            foreach ($opt in @("-i", "-o")) {
                $v = Get-RuleOpt -Rule $r -Opt $opt
                if (Test-StaleIface -Iface $v -Existing $ifaceList) { $staleAll += $v }
            }
        }
        $staleAll = @($staleAll | Sort-Object -Unique)
        if ($staleAll.Count -gt 0) {
            Write-Host "`n  Warning: rules reference non-existent interfaces: $($staleAll -join ', ') (leftover config, safe to clean up)" -ForegroundColor Yellow
        }

        # Traffic flows: -d specific path first, then one per MASQUERADE rule
        $flows = @()
        if ($Destination -and $outInterface) {
            $viaGw = ""
            if ($routeOut) { $viaGw = ([regex]::Match("$routeOut", 'via\s+(\S+)')).Groups[1].Value }
            $gwPart = if ($viaGw) { " via $viaGw" } else { "" }
            $inPart = if ($inInterface) { "in:$inInterface -> " } else { "" }
            $lastHop = if ($outInterface -eq "docker0" -or $outInterface -match "^(docker|br-)") { "container($Destination)" } else { $Destination }
            $flows += "to ${Destination}: local($clientIP) -> $inPart[NAT out:$outInterface$gwPart] -> $lastHop"
        }
        foreach ($r in $masqLines) {
            $src = Get-RuleOpt -Rule $r -Opt "-s"
            $outIf = Get-RuleOpt -Rule $r -Opt "-o"
            if (-not $src) { $src = "any source" }
            if (-not $outIf -or $outIf -eq "*") { continue }
            if ($outIf -match "^!") {
                $flows += "$src -> [NAT out:any iface except $($outIf.TrimStart('!'))] -> external"
            } else {
                $lastHop = if ($outIf -match "^(docker|br-)") { "docker containers (hairpin SNAT)" } else { "external" }
                $flows += "$src -> [NAT out:$outIf] -> $lastHop"
            }
        }
        $flows = @($flows | Select-Object -Unique)
        if ($flows.Count -gt 0) {
            Write-Host "`n  Traffic flows:" -ForegroundColor Cyan
            $i = 1
            foreach ($f in $flows) { Write-Host "    $i. $f" -ForegroundColor White; $i++ }
        } elseif ($fwEnabled -and $natActive -and $inInterface -and $outInterface) {
            $lastHop = if ($outInterface -eq "docker0" -and $Destination) { "container($Destination)" } else { "external" }
            Write-Host "`n  Traffic flow: local($clientIP) -> $inInterface -> [NAT] -> $outInterface -> $lastHop" -ForegroundColor Cyan
        }

        $pkgCheck = ssh $TargetServer "dpkg -l iptables-persistent 2>/dev/null | grep -q '^ii' && echo INSTALLED || echo NOT_INSTALLED" 2>&1
        if ("$pkgCheck".Trim() -eq "INSTALLED") {
            $savedFile = (ssh $TargetServer "test -s /etc/iptables/rules.v4 && echo SAVED || echo NO_SAVE" 2>&1 | Out-String).Trim()
            if ("$savedFile" -eq "SAVED") {
                Write-Host "  Persistence:  saved to /etc/iptables/rules.v4 (survives reboot)" -ForegroundColor Green
            } else {
                Write-Host "  Persistence:  iptables-persistent installed, but no rules saved yet" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Persistence:  not installed (rules lost after reboot)" -ForegroundColor Gray
        }

        return $true
    }

    # Step 2: IP forwarding status
    Write-Host "`n[2/4] IP forwarding status..." -ForegroundColor Cyan
    $forwardStatus = (ssh $TargetServer "cat /proc/sys/net/ipv4/ip_forward" 2>&1).Trim()
    if ($forwardStatus -eq "1") {
        Write-Host "  net.ipv4.ip_forward = 1 (enabled)" -ForegroundColor Green
    } elseif ($forwardStatus -eq "0") {
        Write-Host "  net.ipv4.ip_forward = 0 (disabled)" -ForegroundColor Red
    } else {
        Write-Host "  net.ipv4.ip_forward = $forwardStatus (unknown)" -ForegroundColor Yellow
    }
    $persistConf = (ssh $TargetServer "cat /etc/sysctl.d/99-ipforward.conf 2>/dev/null" 2>$null | Out-String).Trim()
    if ($persistConf) {
        Write-Host "  Persistent: /etc/sysctl.d/99-ipforward.conf -> $($persistConf -split "`n" | Select-Object -First 1)" -ForegroundColor Green
    } else {
        Write-Host "  Persistent: /etc/sysctl.d/99-ipforward.conf not found" -ForegroundColor Gray
    }

    # Step 3: Interface context (same detection logic as enable_nat, honors -d)
    Write-Host "`n[3/4] Interface context..." -ForegroundColor Cyan
    $sshClient = ssh $TargetServer 'echo $SSH_CLIENT' 2>&1
    $clientIP = ($sshClient -split ' ')[0]
    if ($clientIP) {
        $routeIn = ssh $TargetServer "ip route get $clientIP" 2>&1
        $inInterface = ([regex]::Match("$routeIn", 'dev\s+(\S+)')).Groups[1].Value
        if ($inInterface) {
            Write-Host "  Inbound (SSH session):  $inInterface (local IP $clientIP)" -ForegroundColor White
        }
    }
    if ($DevOverride) {
        $outInterface = $DevOverride
        Write-Host "  Outbound (forced -dev): $outInterface" -ForegroundColor White
    } elseif ($Destination) {
        $routeOut = ssh $TargetServer "ip route get $Destination" 2>&1
        $outInterface = ([regex]::Match("$routeOut", 'dev\s+(\S+)')).Groups[1].Value
        if ($outInterface) {
            Write-Host "  Outbound (to $Destination): $outInterface" -ForegroundColor White
            Write-Host "  Route detail: $("$routeOut".Trim())" -ForegroundColor Gray
        } else {
            Write-Host "  Outbound: no route to $Destination" -ForegroundColor Red
            Write-Host "  Route detail: $("$routeOut".Trim())" -ForegroundColor Gray
        }
    } else {
        $defaultRoute = ssh $TargetServer "ip route show default" 2>&1
        $outInterface = ([regex]::Match("$defaultRoute", 'dev\s+(\S+)')).Groups[1].Value
        if ($outInterface) {
            Write-Host "  Outbound (default):     $outInterface" -ForegroundColor White
        }
    }

    # Step 4: iptables rules (NAT table + FORWARD chain)
    Write-Host "`n[4/4] iptables rules..." -ForegroundColor Cyan

    $natRules = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -t nat -L POSTROUTING -n -v --line-numbers" -SudoPassword $sudoPassword
    Write-Host "`n  === NAT table: POSTROUTING chain ===" -ForegroundColor Yellow
    foreach ($line in @($natRules)) {
        if ("$line".Trim()) { Write-Host "  $line" -ForegroundColor Gray }
    }
    if ("$natRules" -match "MASQUERADE") {
        Write-Host "  NAT (MASQUERADE) is ACTIVE" -ForegroundColor Green
    } else {
        Write-Host "  No MASQUERADE rule found (NAT inactive)" -ForegroundColor Red
    }

    $fwdRules = Invoke-SshSudo -TargetServer $TargetServer -Command "iptables -L FORWARD -n -v --line-numbers" -SudoPassword $sudoPassword
    Write-Host "`n  === Filter table: FORWARD chain ===" -ForegroundColor Yellow
    foreach ($line in @($fwdRules)) {
        if ("$line".Trim()) { Write-Host "  $line" -ForegroundColor Gray }
    }

    # Persistence info
    $pkgCheck = ssh $TargetServer "dpkg -l iptables-persistent 2>/dev/null | grep -q '^ii' && echo INSTALLED || echo NOT_INSTALLED" 2>&1
    if ("$pkgCheck".Trim() -eq "INSTALLED") {
        $savedFile = (ssh $TargetServer "test -s /etc/iptables/rules.v4 && echo SAVED || echo NO_SAVE" 2>&1 | Out-String).Trim()
        if ("$savedFile" -eq "SAVED") {
            Write-Host "`n  iptables-persistent: installed, saved rules /etc/iptables/rules.v4 present" -ForegroundColor White
        } else {
            Write-Host "`n  iptables-persistent: installed, no rules saved yet" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n  iptables-persistent: not installed (rules will not survive reboot)" -ForegroundColor Gray
    }

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
        Write-Host "Error: Usage: .\ip.ps1 enable_nat <target_server> [-d <destination>] [-dev <iface>] [-Persist]" -ForegroundColor Red
        Write-Host "  target_server: SSH target (e.g., 192.168.137.2 or user@192.168.137.2)" -ForegroundColor Yellow
        Write-Host "  -d <dest>:     Destination IP to route through (e.g., 172.17.1.122)" -ForegroundColor Yellow
        Write-Host "  -dev <iface>:  Force outbound interface; AUTO = auto-select by ping test; omit = asked when route fails" -ForegroundColor Yellow
        Write-Host "  -Persist:      Save rules across reboot" -ForegroundColor Yellow
        Write-Host "  -p 1:          Alternative for -Persist" -ForegroundColor Yellow
        exit 1
    }

    $targetServer = $AdapterArg
    $destination = $NatDest
    $shouldPersist = $Persist -or (-not [string]::IsNullOrWhiteSpace($ProfileNum))

    if (Enable-NAT -TargetServer $targetServer -Destination $destination -DevInterface $DevInterface -Persist:$shouldPersist) {
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

if ($Command -eq "show_nat") {
    if (-not $AdapterArg) {
        Write-Host "Error: Usage: .\ip.ps1 show_nat <target_server> [-d <dest>] [-dev <iface>] [-h]" -ForegroundColor Red
        Write-Host "  target_server: SSH target (e.g., 192.168.137.2 or user@192.168.137.2)" -ForegroundColor Yellow
        Write-Host "  -d <dest>:     Outbound interface detected via route to <dest> (same as enable_nat)" -ForegroundColor Yellow
        Write-Host "  -dev <iface>:  Force outbound interface display (same as enable_nat -dev)" -ForegroundColor Yellow
        Write-Host "  -h:            Human-friendly summary (recommended)" -ForegroundColor Yellow
        Write-Host "  (no -h):       Raw detail: ip_forward, iptables NAT/FORWARD listings, persistence" -ForegroundColor Yellow
        exit 1
    }

    if (-not (Show-NAT -TargetServer $AdapterArg -Destination $NatDest -DevOverride $DevInterface -Human:$Human)) {
        exit 1
    }
    exit 0
}

if (-not $ProfileNum) {
    Show-AllAdapters
    Show-RoutingTable
    
    Write-Host "`n========================================" -ForegroundColor Magenta
    $editTime = (Get-Item $PSCommandPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    Write-Host "ip.ps1 v$ScriptVersion (edited $editTime)" -ForegroundColor DarkGray
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\ip.ps1                              Show all network info" -ForegroundColor White
    Write-Host "  .\ip.ps1 ping [target]                Test network connectivity" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_first <adapter>          Set adapter as primary (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 route_add <dest> [gateway] [-dev <if>]   Add static route (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 route_del <dest>             Delete route (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_profile <1|2|3> [adapter] Apply network profile" -ForegroundColor White
    Write-Host "  .\ip.ps1 trace_route <target>         Trace route to target" -ForegroundColor White
    Write-Host "  .\ip.ps1 set_ip <adapter> <ip> [mask] Set static IP freely (requires admin)" -ForegroundColor White
    Write-Host "  .\ip.ps1 enable_nat <server> [-d <dest>] [-dev <if|AUTO>] [-Persist]  Enable NAT (route verified by ping)" -ForegroundColor White
    Write-Host "  .\ip.ps1 disable_nat <server> [-d <dest>] [-Persist] Disable NAT on remote Linux (via SSH)" -ForegroundColor White
    Write-Host "  .\ip.ps1 show_nat <server> [-d <dest>] [-h]  Show NAT/forwarding status (-h = simple summary)" -ForegroundColor White
    Write-Host "  .\ip.ps1 version                      Show script version info (edited time + git commit)" -ForegroundColor White
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






