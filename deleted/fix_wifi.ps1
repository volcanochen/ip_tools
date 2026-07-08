#Requires -RunAsAdministrator
# Fix WiFi static IP + remove bad default route for phone hotspot (192.168.137.x)

$ErrorActionPreference = "Stop"
$iface = "wifi网络"
$ip   = "192.168.137.10"
$mask = "255.255.255.0"
$gw   = "192.168.137.1"
$dns1 = "8.8.8.8"
$dns2 = "114.114.114.115"

Write-Host "=== Network Fix Script ===" -ForegroundColor Cyan

# 1) Remove bad default route pointing to dead eth0 (192.168.50.1)
Write-Host "[1/4] Removing stale default route to 192.168.50.1..." -ForegroundColor Yellow
try {
    route delete 0.0.0.0 mask 0.0.0.0 192.168.50.1 | Out-Null
    Write-Host "  OK" -ForegroundColor Green
} catch {
    Write-Host "  Route not present, skipping" -ForegroundColor DarkGray
}

# 2) Set static IP
Write-Host "[2/4] Setting static IP on WiFi: $ip / $mask / gw $gw" -ForegroundColor Yellow
$proc = Start-Process -FilePath "netsh" -ArgumentList @("interface","ip","set","address",$iface,"static",$ip,$mask,$gw) -Wait -PassThru -NoNewWindow -RedirectStandardOutput "stdout.tmp" -RedirectStandardError "stderr.tmp"
Get-Content "stdout.tmp" -ErrorAction SilentlyContinue | Write-Host
Get-Content "stderr.tmp" -ErrorAction SilentlyContinue | Write-Host
Remove-Item "stdout.tmp","stderr.tmp" -ErrorAction SilentlyContinue
if ($proc.ExitCode -ne 0) { throw "netsh set address failed" }

# 3) Set DNS
Write-Host "[3/4] Setting DNS servers..." -ForegroundColor Yellow
Start-Process -FilePath "netsh" -ArgumentList @("interface","ip","set","dns",$iface,"static",$dns1,"primary") -Wait -NoNewWindow | Out-Null
Start-Process -FilePath "netsh" -ArgumentList @("interface","ip","add","dns",$iface,$dns2,"index=2") -Wait -NoNewWindow | Out-Null
Write-Host "  OK" -ForegroundColor Green

# 4) Register DNS
Write-Host "[4/4] Flushing DNS cache..." -ForegroundColor Yellow
ipconfig /flushdns | Out-Null

# Verify
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
ipconfig /all | Select-String -Pattern "wifi|IP|Subnet|Gateway|DNS" -Context 1
route print 0.0.0.0

# Test
Write-Host "`n=== Connectivity Test ===" -ForegroundColor Cyan
Write-Host "Ping gateway $gw..." -NoNewline
$r = ping -n 2 -w 2000 $gw 2>&1
if ($r -match "TTL") { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED" -ForegroundColor Red }

Write-Host "Ping 8.8.8.8..." -NoNewline
$r = ping -n 2 -w 2000 8.8.8.8 2>&1
if ($r -match "TTL") { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED" -ForegroundColor Red }

Write-Host "Resolve www.feishu.cn..." -NoNewline
try {
    $x = [System.Net.Dns]::GetHostAddresses("www.feishu.cn")[0].IPAddressToString
    Write-Host " OK -> $x" -ForegroundColor Green
} catch {
    Write-Host " FAILED" -ForegroundColor Red
}

Write-Host "`nDone. Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
