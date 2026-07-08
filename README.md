# IP Tools

Windows 网络配置管理 PowerShell 脚本，支持 IPv4 和 IPv6 双协议栈。

## 功能特性

- 显示所有网络适配器状态（IPv4/IPv6）
- 显示路由表和默认网关（IPv4/IPv6）
- 网络连通性测试
- 静态路由管理（添加/删除）
- 两种 IP 配置模式：静态 IP 和 DHCP+自定义 DNS
- IP 冲突自动处理
- 设置默认路由优先级（set_first 命令）

## 系统要求

- Windows 10/11 或 Windows Server 2016+
- PowerShell 5.1+
- 管理员权限（修改 IP 配置时需要）

## 使用方法

### 查看网络状态

直接运行脚本（不带参数）显示所有适配器状态和路由信息：

```powershell
.\ip.ps1
```

### 测试网络连通性

```powershell
.\ip.ps1 ping                            # 测试默认目标 (8.8.8.8, Google DNS)
.\ip.ps1 ping baidu.com                  # 测试指定目标
.\ip.ps1 ping 192.168.1.1               # 测试 IP 地址
.\ip.ps1 ping baidu.com "百度DNS"       # 自定义目标 + 描述
```

### 添加静态路由

```powershell
.\ip.ps1 route_add 172.17.1.126              # 添加到默认网关
.\ip.ps1 route_add 172.17.1.126 192.168.1.1  # 指定网关
```

### 删除路由

```powershell
.\ip.ps1 route_del 172.17.1.126/32
```

### 设置主网络适配器

将指定适配器设为默认路由（最高优先级）：

```powershell
.\ip.ps1 set_first "wifi网络"
.\ip.ps1 set_first eth0
```

### 配置静态 IP (Profile 1)

```powershell
.\ip.ps1 set_profile 1 "以太网"
```

参数说明：
- `set_profile 1`: 静态 IP 模式
  - IP: 192.168.137.1
  - Mask: 255.255.255.0
  - DNS: DHCP

### 配置 DHCP+自定义 DNS (Profile 2)

```powershell
.\ip.ps1 set_profile 2 "以太网"
```

参数说明：
- `set_profile 2`: DHCP + 自定义 DNS 模式
  - IP: DHCP 自动获取
  - DNS: 176.16.98.100

## 命令速查

| 命令 | 功能 | 权限 |
|------|------|------|
| `.\ip.ps1` | 显示所有网络信息 | 普通 |
| `.\ip.ps1 ping [目标]` | 测试网络连通性 | 普通 |
| `.\ip.ps1 show_forwarding` | 显示 IP 转发状态 | 普通 |
| `.\ip.ps1 route_add <目标> [网关]` | 添加静态路由 | 管理员 |
| `.\ip.ps1 route_del <目标>` | 删除路由 | 管理员 |
| `.\ip.ps1 set_first <适配器>` | 设置主网络适配器 | 管理员 |
| `.\ip.ps1 set_profile <1\|2> [适配器]` | 应用 IP 配置 | 管理员 |
| `.\ip.ps1 set_ics <源适配器> <目标适配器>` | 配置 ICS 网络共享 | 管理员 |

## 各功能实现方式

以下列出每个命令在底层实际调用的 PowerShell cmdlet、COM 对象或外部命令。

### 查看网络状态

由 `Show-AllAdapters` 与 `Show-RoutingTable` 实现：

- 枚举适配器：`Get-NetAdapter`
- 获取网卡描述：`Get-WmiObject -Class Win32_NetworkAdapter`
- 获取 IPv4 地址：`Get-NetIPAddress -InterfaceAlias <适配器> -AddressFamily IPv4`
- 获取 DNS 服务器：`Get-DnsClientServerAddress -InterfaceAlias <适配器> -AddressFamily IPv4`
- 获取 DHCP 状态：`Get-NetIPInterface -InterfaceAlias <适配器> -AddressFamily IPv4`
- 获取 IPv6 地址与网关：`Get-NetIPAddress` / `Get-NetRoute -AddressFamily IPv6`
- 获取 IPv4/IPv6 路由表：`Get-NetRoute -AddressFamily IPv4` / `-AddressFamily IPv6`

### ping

由 `Test-NetworkConnectivity` 实现：

- 查找默认网关：`Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -eq "0.0.0.0/0"`
- 测试网关连通性：`Test-Connection -ComputerName <网关> -Count 2`
- 测试目标连通性：`Test-Connection -ComputerName <目标> -Count 2`

### route_add

由 `Add-StaticRoute` 实现：

- 若未指定网关，自动查找默认网关：`Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -eq "0.0.0.0/0"`
- 添加静态路由：`New-NetRoute -DestinationPrefix "<目标>/<掩码>" -NextHop <网关> -RouteMetric 10`
  - 若提供 InterfaceIndex，则追加 `-InterfaceIndex <索引>`

### route_del

由 `Remove-StaticRoute` 实现：

- 查找路由：`Get-NetRoute -DestinationPrefix <目标>`
- 删除路由：`Remove-NetRoute -DestinationPrefix <目标> -Confirm:$false`

### set_first

由 `Set-FirstAdapter` 实现：

- 查找适配器：`Get-NetAdapter -Name <适配器>`
- 查找默认网关：`Get-NetRoute -AddressFamily IPv4`
- 获取 IP 配置：`Get-NetIPAddress -InterfaceAlias <适配器> -AddressFamily IPv4`
- 刷新 DHCP（当检测到 APIPA 地址时）：`ipconfig /release <适配器>`、`ipconfig /renew <适配器>`
- 添加默认网关：`New-NetRoute -InterfaceAlias <适配器> -DestinationPrefix "0.0.0.0/0" -NextHop <网关> -RouteMetric 10`
- 调整路由优先级：`Set-NetRoute -InterfaceAlias <适配器> -DestinationPrefix "0.0.0.0/0" -NextHop <网关> -RouteMetric 10`（目标适配器）或 `200`（其他适配器）

### set_profile

- **Profile 1（静态 IP 192.168.137.1/24）**：
  - 检测 IP 冲突：`Get-NetIPAddress -IPAddress <IP>`
  - 迁移冲突 IP 到其他适配器：`netsh interface ip set address <其他适配器> static <新IP> <掩码>`
  - 设置静态 IP：`netsh interface ip set address <适配器> static <IP> <掩码>`
  - 设置 DNS 为 DHCP：`netsh interface ip set dns <适配器> dhcp`

- **Profile 2（DHCP + 自定义 DNS 176.16.98.100）**：
  - 查询当前 DHCP 状态：`Get-NetIPInterface -InterfaceAlias <适配器> -AddressFamily IPv4`
  - 设置 DHCP：`netsh interface ip set address <适配器> dhcp`
  - 设置静态 DNS：`netsh interface ip set dns <适配器> static <DNS>`

- **Profile 3（静态 IP 192.168.50.11/24 + 网关）**：
  - 检测/迁移 IP 冲突
  - 设置静态 IP：`netsh interface ip set address name=<适配器> static <IP> 255.255.255.0`
  - 设置网关：`netsh interface ip set route name=<适配器> gateway=<网关> persist`

### set_ics

由 `Set-ICS` 实现：

- 验证适配器存在：`Get-NetAdapter -Name <适配器>`
- 创建网络共享 COM 对象：`New-Object -ComObject HNetCfg.HNetShare`
- 枚举网络连接：`$netSharingMgr.EnumEveryConnection`
- 获取连接属性：`$netSharingMgr.NetConnectionProps.INetConnectionProps($connection)`
- 获取共享配置：`$netSharingMgr.INetSharingConfigurationForINetConnection($connection)`
- 关闭已有共享：`$netShareCfg.DisableSharing()`
- 启用源适配器共享（Private）：`$netShareCfg.EnableSharing(0)`
- 启用目标适配器共享（Public）：`$netShareCfg.EnableSharing(1)`
- 清除目标 IP 冲突：`Clear-IPConflict`
- 设置目标适配器静态 IP：`netsh interface ip set address <目标适配器> static 192.168.137.1 255.255.255.0`

### trace_route

由 `Trace-Route` 实现：

- DNS 解析：`Resolve-DnsName -Name <目标> -Type A`
- 端口连通性测试：`Test-NetConnection -ComputerName <目标> -Port 80 -InformationLevel Detailed`
- 路由信息：`Get-NetRoute -DestinationPrefix <目标>`

### 已知未实现/调用缺失的命令

- `show_forwarding`：README 中已列出，但当前 `ip.ps1` 中未实现该命令处理逻辑。
- `set_ip`：命令处理逻辑中调用 `Set-StaticIP`，但脚本中未定义该函数，因此当前不可用。

## 查看 IP 转发状态

使用 `show_forwarding` 命令查看当前网络适配器的 IP 转发状态和网络共享关系。

### 用法

```powershell
.\ip.ps1 show_forwarding
```

### 示例输出

```
=== IP Forwarding Status ===

Adapter           Status   IPv4              Gateway       IPv4Fwd IPv6Fwd
-------           ------   ----              -------       ------- -------      
eth0               Up       192.168.137.1    -              Yes    No
wifi网络           Up       192.168.50.73    192.168.50.1   Yes    No

=== Network Sharing Relationships ===

  [wifi网络] (192.168.50.73)
    Forwarding: IPv4=Yes, IPv6=No
    Internet via: 192.168.50.1

  [eth0] (192.168.137.1)
    Forwarding: IPv4=Yes, IPv6=No
```

### 说明

- **IPv4Fwd/IPv6Fwd**: 是否启用了 IP 转发（Yes = 已启用）
- **Gateway**: 默认网关（如有）
- **Internet via**: 显示通过哪个网关访问互联网

## 配置 ICS 网络共享

使用 `set_ics` 命令将一个网络适配器的网络连接分享给另一个适配器。

### 用法

```powershell
.\ip.ps1 set_ics <源适配器> <目标适配器>
```

### 示例

```powershell
# 将 "wifi网络" 的网络分享给 "eth0"
.\ip.ps1 set_ics "wifi网络" "eth0"
```

### 说明

- **源适配器**: 提供网络连接的适配器（通常连接到互联网）
- **目标适配器**: 接收共享网络的适配器（连接到内网或其他设备）
- 配置后，目标适配器将自动设置 IP 为 192.168.137.1
- 需要管理员权限

## 示例输出

#### 查看网络状态（新版格式）

```
=== Network Adapters (IPv4/IPv6) ===

[wifi 网络] enabled, up, 650 Mbps
  (Description: Realtek PCIe GBE Family Controller)
     MAC: AA-BB-CC-DD-EE-FF
     IPv4: 192.168.50.73/24
     DHCP: Enabled
     Gateway: 192.168.50.1
     DNS:  192.168.50.1

[eth0] enabled, up, 1 Gbps
  (Description: VirtualBox Host-Only Ethernet Adapter)
     MAC: 0A-00-27-00-00-1A
     IPv4: 192.168.137.1/24
     DHCP: Enabled
     Gateway: -
     DNS:  (none)

[以太网 3] enabled, up, 1 Gbps
  (Description: VirtualBox Host-Only Ethernet Adapter)
     MAC: 0A-00-27-00-00-1B
     IPv4: 169.254.208.75/16   (APIPA, no DHCP)
     DHCP: failed to APIPA
     Gateway: -
     DNS:  (none)

[OpenVPN Data Channel Offload for Surfshark] enabled, down, 1 Gbps
  (Description: OpenVPN Data Channel Offload)
     MAC: 38-A-7-46-39-5C-5
     IPv4: 169.254.78.9/16   (APIPA, no DHCP)
     DHCP: failed to APIPA
```

状态颜色说明：
- **up** → 绿色，**down** → 红色
- **valid IP** → Cyan（不显示状态文本）
- **APIPA** → 黄色 + 显示"failed to APIPA"
- **no DHCP** → 灰色

### 测试网络连通性

```
=== Network Connectivity Test ===
Testing gateway: 192.168.50.1 ... OK
Testing baidu.com ... OK (avg: 40ms)
```

### 设置主网络适配器

```
=== Setting [wifi网络] as primary network adapter ===
  Found adapter: [wifi网络]

  Current default gateways:
    192.168.50.1 dev wifi网络 metric 35

  Setting [wifi网络] gateway priority to highest...
    [wifi网络] already has highest priority (metric 10)

Done!
```

## 适配器状态说明

| 状态 | 说明 |
|------|------|
| `valid IP` | 有效的 IPv4 地址 |
| `APIPA (no DHCP)` | 169.254.x.x 地址，DHCP 失败 |
| `no IP` | 未配置 IP 地址 |

## 注意事项

1. 修改 IP 配置需要管理员权限，请以管理员身份运行 PowerShell
2. 修改网络适配器名称时，请确保使用正确的适配器名称
3. 静态 IP 模式会先检测目标 IP 是否被其他适配器使用，如有冲突会自动迁移
4. 建议在修改前先运行不带参数的命令查看当前网络状态
5. `set_first` 命令会自动调整其他适配器的路由优先级

## 故障排除

如果执行失败，请检查：
1. 是否以管理员权限运行
2. 适配器名称是否正确
3. 指定的 IP 是否已被其他设备使用
4. 网络适配器是否被禁用
5. 网络线路是否正常连接

## APIPA 说明

APIPA（Automatic Private IP Addressing）是 Windows 的自动私有 IP 地址分配机制。当 DHCP 服务器不可用时，Windows 会自动分配 169.254.0.0/16 范围内的 IP 地址。

APIPA 地址无法访问互联网，只能实现同网段内的通信。如果看到 APIPA 地址，说明 DHCP 请求失败，需要检查：
- DHCP 服务器是否运行
- 网络线路是否正常
- 是否需要手动配置 IP

## ICS 验证标准

详细的功能验证标准和测试脚本请参考 [ICS_VERIFICATION.md](ICS_VERIFICATION.md)。

该文档包含：
- 完整的工作配置状态记录
- 验证脚本 (verify_ics.ps1)
- 自动配置目标
- 已知问题和解决方案
