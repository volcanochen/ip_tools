$mgr = New-Object -ComObject HNetCfg.HNetShare
Write-Host "HNetCfg Methods:"
$mgr | Get-Member -MemberType Method | Select-Object Name
Write-Host ""
Write-Host "Enumerating connections..."
$connections = $mgr.EnumEveryConnection()
Write-Host "Found $($connections.Count) connections"
foreach ($conn in $connections) {
    $props = $null
    try {
        $props = $conn
        Write-Host "Connection: $conn"
    } catch {
        Write-Host "Error getting props for $conn"
    }
}
