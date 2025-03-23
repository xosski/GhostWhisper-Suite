# Modules/GhostLogger.ps1
# Lightweight ghost activity logger with time-based tracking

function Write-GhostLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$LogFile = "$env:ProgramData\ghost_ops_log.txt"
    )

    $timestamp = Get-Date -Format o
    $entry = "[$timestamp] $Message"

    try {
        Add-Content -Path $LogFile -Value $entry
    }
    catch {
        Write-Warning "[GhostLogger] Failed to write to log: $LogFile"
    }
}

function Read-GhostLog {
    param(
        [string]$LogFile = "$env:ProgramData\ghost_ops_log.txt",
        [int]$Tail = 25
    )

    if (Test-Path $LogFile) {
        Get-Content -Path $LogFile -Tail $Tail | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Warning "[GhostLogger] Log file not found: $LogFile"
    }
}

function Clear-GhostLog {
    param(
        [string]$LogFile = "$env:ProgramData\ghost_ops_log.txt"
    )

    if (Test-Path $LogFile) {
        try {
            Clear-Content -Path $LogFile
            Write-Host "[GhostLogger] Cleared log: $LogFile"
            Write-GhostLog -Message "Log cleared by $env:USERNAME"
        }
        catch {
            Write-Warning "[GhostLogger] Failed to clear log."
        }
    }
    else {
        Write-Host "[GhostLogger] No log file to clear."
    }
}

function Parse-GhostLog {
    param(
        [string]$LogFile = "$env:ProgramData\ghost_ops_log.txt",
        [string]$Filter = ""
    )

    if (Test-Path $LogFile) {
        $entries = Get-Content -Path $LogFile
        if ($Filter) {
            $entries = $entries | Where-Object { $_ -like "*$Filter*" }
        }
        $entries | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Warning "[GhostLogger] Cannot parse, log file not found."
    }
}
