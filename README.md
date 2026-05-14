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
| `.\ip.ps1 route_add <目标> [网关]` | 添加静态路由 | 管理员 |
| `.\ip.ps1 route_del <目标>` | 删除路由 | 管理员 |
| `.\ip.ps1 set_first <适配器>` | 设置主网络适配器 | 管理员 |
| `.\ip.ps1 set_profile <1\|2> [适配器]` | 应用 IP 配置 | 管理员 |

## 示例输出

### 查看网络状态

```
=== IPv4 Network Adapters ===

  [wifi网络] 650 Mbps - valid IP
    IPv4: 192.168.50.73/24
    DHCP: Enabled
    DNS:  192.168.50.1

  [以太网 3] 1 Gbps - APIPA (no DHCP)
    IPv4: 169.254.208.75/16
    DHCP: Enabled

=== IPv6 Network Adapters ===

  [wifi网络]
    IPv6: 240e:3bb:649:ea00:f432:8f5d:5ded:ecef/128
    Gateway: fe80::42b0:76ff:fe2c:cee8

=== Default Gateway ===
  192.168.50.1 dev wifi网络 metric 0

=== Network Connectivity Test ===
Testing gateway: 192.168.50.1 ... OK
Testing 8.8.8.8 (Google DNS) ... OK (avg: 35ms)
```

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
