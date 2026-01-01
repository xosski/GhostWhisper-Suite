# === Modules/Anomaly_Detector.ps1 ===
# Detects virtualization anomalies such as rootkit cloaking and syscall redirection

function Test-VirtualizationAnomalies {
    Write-Host "[*] Scanning for virtualization anomalies..."
    $anomalies = @()

    # === 1. Check for hidden processes ===
    try {
        $tasklist = tasklist /fo csv | ConvertFrom-Csv
        $wmiprocs = Get-WmiObject Win32_Process
        $hidden = $wmiprocs | Where-Object { $_.Name -notin $tasklist."Image Name" }

        if ($hidden.Count -gt 0) {
            Write-Warning "[!] Hidden processes detected (possible rootkit):"
            $hidden | ForEach-Object { Write-Host " - $($_.Name) ($($_.ProcessId))" }
            $anomalies += $hidden
        }
    }
    catch {
        Write-Warning "[!] Failed to check for hidden processes"
    }

    # === 2. Syscall test using low-level timing anomaly ===
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Get-Process | Out-Null
        $sw.Stop()

        if ($sw.ElapsedMilliseconds -gt 300) {
            Write-Warning "[!] Syscall timing anomaly detected (>300ms): $($sw.ElapsedMilliseconds)ms"
            $anomalies += "Syscall latency"
        }
    }
    catch {
        Write-Warning "[!] Failed syscall timing test"
    }

    # === 3. Kernel driver cloak check ===
    try {
        $drivers = Get-WmiObject Win32_SystemDriver | Where-Object { $_.State -eq "Running" }
        $invisible = $drivers | Where-Object { $_.PathName -eq $null -or $_.PathName -eq "" }
        if ($invisible.Count -gt 0) {
            Write-Warning "[!] Invisible or cloaked kernel drivers detected:"
            $invisible | ForEach-Object { Write-Host " - $($_.Name)" }
            $anomalies += $invisible
        }
    }
    catch {
        Write-Warning "[!] Failed to enumerate kernel drivers"
    }

    if ($anomalies.Count -eq 0) {
        Write-Host "[✓] No anomalies detected."
    }
    else {
        "[!] Virtualization Anomalies Detected at $(Get-Date)" | Out-File -Append -FilePath "$PSScriptRoot\..\ghost_ops_log.txt"
    }

    return $anomalies
}
