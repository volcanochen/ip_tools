# ICS 网络共享配置验证标准

## 当前已验证的工作配置

以下配置已通过手动配置验证，能够正常工作。

### 网络拓扑

```
互联网
  ↓
[wifi网络] (192.168.50.73/24, 网关: 192.168.50.1)
  ↓ 共享
[eth0] (192.168.137.1/24)
  ↓
连接到目标设备
```

### 验证标准

成功配置 ICS 后，必须满足以下所有条件：

---

## 1. 适配器状态

### wifi网络 (源适配器)
```powershell
Get-NetAdapter -Name "wifi网络"
```
**期望结果：**
- Status: Up
- LinkSpeed: 866.7 Mbps 或类似
- IPv4: 192.168.50.73
- DHCP: Enabled
- 默认网关: 192.168.50.1

### eth0 (目标适配器)
```powershell
Get-NetAdapter -Name "eth0"
```
**期望结果：**
- Status: Up
- LinkSpeed: 1 Gbps
- IPv4: 192.168.137.1
- DHCP: Disabled

---

## 2. IP 转发状态

```powershell
Get-NetIPInterface | Where-Object { $_.InterfaceAlias -in @('wifi网络', 'eth0') } | Select-Object InterfaceAlias, AddressFamily, Forwarding
```
**期望结果：**
```
InterfaceAlias  AddressFamily  Forwarding
--------------  -------------  ----------
eth0            IPv4           Enabled
eth0            IPv6           Disabled
wifi网络        IPv4           Enabled
wifi网络        IPv6           Disabled
```

---

## 3. IP 地址配置

### wifi网络
```powershell
netsh interface ip show config "wifi网络"
```
**期望结果：**
```
IP 地址:                           192.168.50.73
子网掩码:                          255.255.255.0
默认网关:                          192.168.50.1
```

### eth0
```powershell
netsh interface ip show config "eth0"
```
**期望结果：**
```
IP 地址:                           192.168.137.1
子网掩码:                          255.255.255.0
DHCP:                             已禁用
```

---

## 4. 路由表

### 默认路由
```powershell
route print | findstr "0.0.0.0"
```
**期望结果：**
```
0.0.0.0          0.0.0.0     192.168.50.1      wifi网络
```

### eth0 路由
```powershell
route print | findstr "192.168.137"
```
**期望结果：**
```
192.168.137.0    255.255.255.0      在链路上       eth0    25
192.168.137.1    255.255.255.255      在链路上       eth0    256
```

---

## 5. NAT 配置

```powershell
netsh routing ip nat show interface
```
**期望结果：**
- wifi网络 适配器应配置为 NAT 模式 (Full)

---

## 6. 连通性测试

### 从 eth0 网络访问互联网
```powershell
# 从 eth0 (192.168.137.x) 网络中的设备测试
ping 8.8.8.8
ping www.baidu.com
```
**期望结果：**
- 能够 ping 通外部 IP (8.8.8.8)
- 能够 ping 通域名 (www.baidu.com)

### 从主机测试 eth0 网络
```powershell
ping 192.168.137.1
```
**期望结果：**
- 能够 ping 通

---

## 7. ICS 功能验证脚本

将以下脚本保存为 `verify_ics.ps1`：

```powershell
Write-Host "=== ICS Configuration Verification ===" -ForegroundColor Cyan
Write-Host ""

$success = $true

# 1. Check wifi网络 status
Write-Host "[1/7] Checking wifi网络 adapter..." -NoNewline
$wifiAdapter = Get-NetAdapter -Name "wifi网络" -ErrorAction SilentlyContinue
if ($wifiAdapter.Status -eq "Up") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

# 2. Check eth0 status
Write-Host "[2/7] Checking eth0 adapter..." -NoNewline
$ethAdapter = Get-NetAdapter -Name "eth0" -ErrorAction SilentlyContinue
if ($ethAdapter.Status -eq "Up") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

# 3. Check eth0 IP
Write-Host "[3/7] Checking eth0 IP (192.168.137.1)..." -NoNewline
$ethIP = Get-NetIPAddress -InterfaceAlias "eth0" -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($ethIP.IPAddress -eq "192.168.137.1") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

# 4. Check IP forwarding on eth0
Write-Host "[4/7] Checking IP forwarding on eth0..." -NoNewline
$ethFwd = Get-NetIPInterface -InterfaceAlias "eth0" -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($ethFwd.Forwarding -eq "Enabled") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

# 5. Check IP forwarding on wifi网络
Write-Host "[5/7] Checking IP forwarding on wifi网络..." -NoNewline
$wifiFwd = Get-NetIPInterface -InterfaceAlias "wifi网络" -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($wifiFwd.Forwarding -eq "Enabled") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

# 6. Check default gateway
Write-Host "[6/7] Checking default gateway..." -NoNewline
$gateway = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Select-Object -First 1
if ($gateway.NextHop -eq "192.168.50.1") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

# 7. Ping test
Write-Host "[7/7] Testing internet connectivity..." -NoNewline
$pingResult = Test-Connection -ComputerName 8.8.8.8 -Count 2 -ErrorAction SilentlyContinue
if ($pingResult) {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FAILED" -ForegroundColor Red
    $success = $false
}

Write-Host ""
if ($success) {
    Write-Host "=== All ICS checks passed! ===" -ForegroundColor Green
} else {
    Write-Host "=== Some ICS checks failed ===" -ForegroundColor Red
}
```

---

## 8. 自动配置目标

`ip.ps1 set_ics` 命令必须实现以下功能：

### 配置步骤

1. **禁用现有配置**
   - 重置 NAT 配置
   - 禁用现有 IP 转发

2. **配置 NAT**
   ```powershell
   netsh routing ip nat install
   netsh routing ip nat add interface "wifi网络" mode=full
   netsh routing ip nat add addressrange start=192.168.137.2 end=192.168.137.254 mask=255.255.255.0
   netsh routing ip nat set interface "wifi网络" mode=full
   ```

3. **启用 IP 转发**
   ```powershell
   netsh interface ipv4 set interface "eth0" forwarding=enabled
   netsh interface ipv4 set interface "wifi网络" forwarding=enabled
   ```

4. **设置目标适配器 IP**
   ```powershell
   netsh interface ip set address "eth0" static 192.168.137.1 255.255.255.0
   ```

5. **配置路由规则**
   ```powershell
   netsh interface ipv4 add route 192.168.137.0/24 "eth0" 192.168.137.1
   ```

### 验证

配置完成后，运行 `verify_ics.ps1` 或 `.\ip.ps1 show_forwarding` 验证所有条件。

---

## 9. 已知问题

- `netsh routing ip nat` 命令在某些 Windows 版本中可能需要管理员权限
- COM 对象 `HNetCfg.HNetShare` 的 ICS API 在某些环境下访问受限
- NAT 配置通过 netsh 命令实现作为备选方案

---

## 10. 参考资料

- Windows NAT 实现: https://docs.microsoft.com/en-us/windows-hardware/drivers/network/nat-support-in-windows
- ICS 配置: https://docs.microsoft.com/en-us/windows/win32/netgloss/ics
