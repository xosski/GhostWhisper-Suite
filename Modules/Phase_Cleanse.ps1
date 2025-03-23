function Start-CleansePhase {
    param([array]$FilesToWipe, [switch]$Log)

    Write-Host "[*] Cleanse Phase: Wiping files..."
    foreach ($file in $FilesToWipe) {
        try {
            $rand = Get-Random -Minimum 1 -Maximum 5
            for ($i = 0; $i -lt $rand; $i++) {
                Set-Content -Path $file.FullName -Value ("x" * $file.Length)
            }
            Remove-Item -Path $file.FullName -Force
            Write-Host "[✓] Cleansed: $($file.FullName)"
            if ($Log) {
                "CLEANSED: $($file.FullName)" | Out-File -Append -FilePath "$PSScriptRoot\..\ghost_ops_log.txt"
            }
        }
        catch {
            Write-Host "[-] Failed to wipe: $($file.FullName)"
        }
    }
}
