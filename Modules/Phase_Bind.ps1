function Start-BindPhase {
    param([array]$FilesToCheck)

    Write-Host "[*] Bind Phase: Identifying active threats..."
    $suspended = @()

    foreach ($proc in Get-Process) {
        foreach ($file in $FilesToCheck) {
            if ($proc.Path -eq $file.FullName) {
                try {
                    Suspend-Process -Id $proc.Id
                    Write-Host "[!] Suspended: $($proc.Name)"
                    $suspended += $proc.Name
                }
                catch {
                    Write-Host "[-] Failed to suspend: $($proc.Name)"
                }
            }
        }
    }
    return $suspended
}
