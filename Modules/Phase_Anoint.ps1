# === Modules/Phase_Anoint.ps1 ===
function Start-AnointPhase {
    param([string]$Path, [switch]$Log)

    Write-Host "[*] Anoint Phase: Scanning target directory..."
    $suspectFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Length -gt 10KB -and ($_.Extension -in '.exe', '.dll', '.ps1', '.bat', '.vbs')
    }

    foreach ($file in $suspectFiles) {
        $hash = Get-FileHash $file.FullName -Algorithm SHA256
        Write-Host "[+] Found: $($file.FullName) | SHA256: $($hash.Hash)"
        if ($Log) {
            "$($file.FullName),$($hash.Hash)" | Out-File -Append -FilePath "$PSScriptRoot\..\ghost_ops_log.txt"
        }
    }
    return $suspectFiles
}
