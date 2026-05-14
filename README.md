# IP Tools

Windows网络配置管理PowerShell脚本。

## 功能特性

- 显示所有网络适配器状态
- 显示路由表和默认网关
- 两种IP配置模式：静态IP和DHCP+自定义DNS
- IP冲突自动处理
- 设置默认路由优先级（set_first命令）

## 系统要求

- Windows 10/11 或 Windows Server 2016+
- PowerShell 5.1+
- 管理员权限（修改IP配置时需要）

## 使用方法

### 查看网络状态

直接运行脚本（不带参数）显示所有适配器状态和路由信息：

```powershell
.\ip.ps1
```

### 配置静态IP (Profile 1)

```powershell
.\ip.ps1 -Adapter "以太网" -Profile 1
```

参数说明：
- `-Adapter`: 网络适配器名称（默认: eth1）
- `-Profile 1`: 静态IP模式
  - IP: 192.168.137.1
  - Mask: 255.255.255.0
  - DNS: DHCP

### 配置DHCP+自定义DNS (Profile 2)

```powershell
.\ip.ps1 -Adapter "以太网" -Profile 2
```

参数说明：
- `-Profile 2`: DHCP + 自定义DNS模式
  - IP: DHCP自动获取
  - DNS: 176.16.98.100

### 短参数形式

```powershell
.\ip.ps1 -a "以太网" -p 1
```

## 示例

查看网络状态：
```
=== All Network Adapters ===
  [以太网] enabled, up
    IP:     192.168.1.100
    PrefixLength: 24
    DHCP:   Disabled
    DNS:    8.8.8.8, 8.8.4.4

=== Routing Table ===
  192.168.1.0/24 via direct dev 以太网

=== Default Gateway ===
  192.168.1.1 dev 以太网 metric 100
```

设置静态IP：
```
Profile 1: Setting [以太网] to static IP: 192.168.137.1 / 255.255.255.0 ...
  Setting [以太网] IP to static 192.168.137.1 / 255.255.255.0 ...

Done!
```

## 注意事项

1. 修改IP配置需要管理员权限，请以管理员身份运行PowerShell
2. 修改网络适配器名称时，请确保使用正确的适配器名称
3. 静态IP模式会先检测目标IP是否被其他适配器使用，如有冲突会自动迁移
4. 建议在修改前先运行不带参数的命令查看当前网络状态

## 故障排除

如果执行失败，请检查：
1. 是否以管理员权限运行
2. 适配器名称是否正确
3. 指定的IP是否已被其他设备使用
4. 网络适配器是否被禁用
