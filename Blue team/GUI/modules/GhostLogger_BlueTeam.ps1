Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
GhostLogger_BlueTeam.ps1
Defensive logging / baseline / change-monitoring module for blue teams.
#>

$script:GhostLoggerState = [ordered]@{
    SessionId = [guid]::NewGuid().ToString()
    CaseId = $null
    Operator = $env:USERNAME
    Hostname = $env:COMPUTERNAME
    StartTime = (Get-Date)
    BaseDir = Join-Path $env:ProgramData 'GhostShield'
    LogDir = Join-Path $env:ProgramData 'GhostShield\Logs'
    StateDir = Join-Path $env:ProgramData 'GhostShield\State'
    TranscriptPath = $null
    JsonLogPath = $null
    BaselinePath = $null
    PollSeconds = 60
    Timer = $null
    Monitoring = $false
}

function Initialize-GhostLogger {
    [CmdletBinding()]
    param(
        [string]$CaseId,
        [int]$PollSeconds = 60
    )

    New-Item -ItemType Directory -Path $script:GhostLoggerState.BaseDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:GhostLoggerState.LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:GhostLoggerState.StateDir -Force | Out-Null

    $script:GhostLoggerState.CaseId = if ($CaseId) { $CaseId } else { "CASE-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
    $script:GhostLoggerState.PollSeconds = $PollSeconds
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    $script:GhostLoggerState.TranscriptPath = Join-Path $script:GhostLoggerState.LogDir "Transcript_$stamp.txt"
    $script:GhostLoggerState.JsonLogPath = Join-Path $script:GhostLoggerState.LogDir "Events_$stamp.jsonl"
    $script:GhostLoggerState.BaselinePath = Join-Path $script:GhostLoggerState.StateDir 'baseline.json'

    Start-Transcript -Path $script:GhostLoggerState.TranscriptPath -Force | Out-Null
    Write-GhostLog -Level INFO -Component Bootstrap -Message 'Ghost logger initialized' -Data @{
        caseId = $script:GhostLoggerState.CaseId
        sessionId = $script:GhostLoggerState.SessionId
        operator = $script:GhostLoggerState.Operator
        hostname = $script:GhostLoggerState.Hostname
        pollSeconds = $script:GhostLoggerState.PollSeconds
    }
}

function Write-GhostLog {
    [CmdletBinding()]
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR','CRITICAL')]
        [string]$Level = 'INFO',
        [string]$Component = 'GhostLogger',
        [Parameter(Mandatory)]
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (-not $script:GhostLoggerState.JsonLogPath) {
        return
    }

    $entry = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        level = $Level
        component = $Component
        message = $Message
        caseId = $script:GhostLoggerState.CaseId
        sessionId = $script:GhostLoggerState.SessionId
        operator = $script:GhostLoggerState.Operator
        hostname = $script:GhostLoggerState.Hostname
        data = $Data
    }

    try {
        ($entry | ConvertTo-Json -Depth 10 -Compress) | Add-Content -LiteralPath $script:GhostLoggerState.JsonLogPath -Encoding UTF8
    } catch {}
}

function Get-SystemChangeSnapshot {
    [CmdletBinding()]
    param()

    $signedInUsers = @()
    if (Get-Command -Name Get-SignedInUsersBaseline -ErrorAction SilentlyContinue) {
        $signedInUsers = @(Get-SignedInUsersBaseline)
    }

    [pscustomobject]@{
        CapturedAt = (Get-Date).ToString('o')
        Hostname = $env:COMPUTERNAME
        SignedInUsers = $signedInUsers
    }
}

function Save-GhostBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Snapshot
    )

    $Snapshot | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:GhostLoggerState.BaselinePath -Encoding UTF8 -Force
    Write-GhostLog -Level INFO -Component Baseline -Message 'Baseline saved' -Data @{ path = $script:GhostLoggerState.BaselinePath }
    return $script:GhostLoggerState.BaselinePath
}

function Get-SignedInUsersSnapshot {
    [CmdletBinding()]
    param()

    if (Get-Command -Name Get-SignedInUsersBaseline -ErrorAction SilentlyContinue) {
        return @(Get-SignedInUsersBaseline)
    }

    try {
        return @(Get-CimInstance Win32_LoggedOnUser -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Antecedent = $_.Antecedent
                Dependent = $_.Dependent
            }
        })
    } catch {
        return @()
    }
}

function Start-GhostMonitoring {
    [CmdletBinding()]
    param(
        [int]$PollSeconds = $script:GhostLoggerState.PollSeconds
    )

    if ($script:GhostLoggerState.Monitoring) {
        return $true
    }

    $script:GhostLoggerState.PollSeconds = $PollSeconds
    $timer = [System.Timers.Timer]::new([Math]::Max(5, ($PollSeconds * 1000)))
    $timer.AutoReset = $true

    $action = {
        try {
            if (Get-Command -Name Get-SignedInUsersSnapshot -ErrorAction SilentlyContinue) {
                $users = Get-SignedInUsersSnapshot
                Write-GhostLog -Level DEBUG -Component Monitoring -Message 'Monitoring heartbeat' -Data @{ userCount = @($users).Count }
            }
        } catch {
            Write-GhostLog -Level WARN -Component Monitoring -Message 'Monitoring iteration error' -Data @{ error = $_.Exception.Message }
        }
    }

    Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier 'GhostShield.Monitoring' -Action $action | Out-Null
    $timer.Start()

    $script:GhostLoggerState.Timer = $timer
    $script:GhostLoggerState.Monitoring = $true
    Write-GhostLog -Level INFO -Component Monitoring -Message 'Continuous monitoring started' -Data @{ pollSeconds = $PollSeconds }
    return $true
}

function Stop-GhostMonitoring {
    [CmdletBinding()]
    param()

    if ($script:GhostLoggerState.Timer) {
        try {
            $script:GhostLoggerState.Timer.Stop()
            $script:GhostLoggerState.Timer.Dispose()
        } catch {}
    }

    Unregister-Event -SourceIdentifier 'GhostShield.Monitoring' -ErrorAction SilentlyContinue
    Remove-Job -Name 'GhostShield.Monitoring' -ErrorAction SilentlyContinue

    $script:GhostLoggerState.Timer = $null
    $script:GhostLoggerState.Monitoring = $false
    Write-GhostLog -Level INFO -Component Monitoring -Message 'Continuous monitoring stopped'
    return $true
}

function Get-GhostLoggerStatus {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        SessionId = $script:GhostLoggerState.SessionId
        CaseId = $script:GhostLoggerState.CaseId
        Operator = $script:GhostLoggerState.Operator
        Hostname = $script:GhostLoggerState.Hostname
        StartTime = $script:GhostLoggerState.StartTime
        TranscriptPath = $script:GhostLoggerState.TranscriptPath
        JsonLogPath = $script:GhostLoggerState.JsonLogPath
        BaselinePath = $script:GhostLoggerState.BaselinePath
        PollSeconds = $script:GhostLoggerState.PollSeconds
        Monitoring = $script:GhostLoggerState.Monitoring
    }
}

function Stop-GhostLogger {
    [CmdletBinding()]
    param()

    Stop-GhostMonitoring -ErrorAction SilentlyContinue | Out-Null
    Write-GhostLog -Level INFO -Component Bootstrap -Message 'Ghost logger stopped'
    try { Stop-Transcript | Out-Null } catch {}
}

Export-ModuleMember -Function @(
    'Initialize-GhostLogger',
    'Stop-GhostLogger',
    'Write-GhostLog',
    'Get-GhostLoggerStatus',
    'Get-SystemChangeSnapshot',
    'Save-GhostBaseline',
    'Get-SignedInUsersSnapshot',
    'Start-GhostMonitoring',
    'Stop-GhostMonitoring'
)
