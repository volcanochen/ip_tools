Get-NetIPInterface | Where-Object { $_.InterfaceAlias -eq 'eth0' -or $_.InterfaceAlias -eq 'wifi网络' } | Select-Object InterfaceAlias, AddressFamily, Forwarding
