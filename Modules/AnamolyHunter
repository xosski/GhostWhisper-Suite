# AnomalyHunter.ps1 - Virtualization Anomaly Detection & Auto-Remediation for GhostWhisper Suite
# Detects syscall redirection, rootkit behavior, timing skews, and triggers ExorcistMode if anomalies are confirmed

function Test-SyscallRedirection {
    Write-Host "[*] Testing for syscall redirection..."
    $pre = Get-Process | Measure-Object | Select-Object -ExpandProperty Count
    Start-Sleep -Milliseconds 50
    $post = Get-Process | Measure-Object | Select-Object -ExpandProperty Count
    
    if ([math]::Abs($pre - $post) -gt 10) {
        Write-Warning "[!] Sudden syscall discrepancy detected ($pre → $post)"
        return $true
    }
    return $false
}

function Test-TimingSkew {
    Write-Host "[*] Testing for timing anomalies..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds 100
    $sw.Stop()
    
    if ($sw.ElapsedMilliseconds -gt 150) {
        Write-Warning "[!] Timing skew suggests virtualization interception ($($sw.ElapsedMilliseconds)ms)"
        return $true
    }
    return $false
}

function Test-RootkitArtifacts {
    Write-Host "[*] Scanning for hidden rootkit artifacts..."
    $kernel32 = "C:\Windows\System32\kernel32.dll"
    if (-not (Test-Path $kernel32)) {
        Write-Warning "[!] Kernel32 missing or cloaked!"
        return $true
    }
    return $false
}

function Invoke-AnomalyRemediation {
    param([string]$TargetPath = "$env:TEMP", [switch]$Log)

    Write-Host "[+] Anomalies confirmed. Invoking full Exorcist sweep on: $TargetPath"
    . "$PSScriptRoot\ExorcistMode.ps1"
    Start-Exorcism -Path $TargetPath -Log:$Log

    Add-Content "$env:ProgramData\ghost_ops_log.txt" "[`(AnomalyRemediation`)] Sweep initiated at $(Get-Date)"
}

function Start-AnomalyHunt {
    param([string]$Path = "$env:TEMP", [switch]$Log)

    $flags = @()
    if (Test-SyscallRedirection) { $flags += "SyscallRedirection" }
    if (Test-TimingSkew) { $flags += "TimingSkew" }
    if (Test-RootkitArtifacts) { $flags += "RootkitDetected" }

    if ($flags.Count -gt 0) {
        Write-Host "[!] Anomalies Detected:`n - $($flags -join "`n - ")" -ForegroundColor Red
        Invoke-AnomalyRemediation -TargetPath $Path -Log:$Log
    }
    else {
        Write-Host "[✓] No virtualization anomalies detected."
    }
}

# Optional standalone execution
if ($MyInvocation.InvocationName -eq ".\\AnomalyHunter.ps1") {
    Start-AnomalyHunt -Path "$env:TEMP" -Log
}
