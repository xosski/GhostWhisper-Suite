Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
GhostShieldBootstrap.ps1
Blue-team defensive bootstrap skeleton.

Purpose
- Safe incident response / triage launcher
- Signed-module style loading pattern (skeleton)
- Case/session initialization
- Defensive operator menu
- Logging, baseline creation, monitoring, triage, containment, reporting hooks

This is a framework skeleton. Most actions delegate to module functions in this folder.
#>

# -----------------------------------------------------------------------------
# Script metadata
# -----------------------------------------------------------------------------
$script:Version = '0.1.0-blue'
$script:BuildDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$script:BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:CaseId = $null
$script:SessionStart = Get-Date
$script:IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
$script:ContainmentState = 'NotStarted'
$script:EvidenceCount = 0
$script:HighSeverityCount = 0
$script:LoadedModules = @()
$script:FailedModules = @()
$script:Mode = 'Audit'
$script:WhatIfMode = $false

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
function Show-Banner {
    Write-Host ''
    Write-Host '  ░██████╗░██╗░░██╗░█████╗░░██████╗████████╗' -ForegroundColor DarkCyan
    Write-Host '  ██╔════╝░██║░░██║██╔══██╗██╔════╝╚══██╔══╝' -ForegroundColor DarkCyan
    Write-Host '  ██║░░██╗░███████║██║░░██║╚█████╗░░░░██║░░░' -ForegroundColor Cyan
    Write-Host '  ██║░░╚██╗██╔══██║██║░░██║░╚═══██╗░░░██║░░░' -ForegroundColor Cyan
    Write-Host '  ╚██████╔╝██║░░██║╚█████╔╝██████╔╝░░░██║░░░' -ForegroundColor White
    Write-Host '  ░╚═════╝░╚═╝░░╚═╝░╚════╝░╚═════╝░░░░╚═╝░░░' -ForegroundColor White
    Write-Host ''
    Write-Host "  [🛡️] GhostShield Bootstrap v$script:Version" -ForegroundColor DarkGray
    Write-Host '  [*] Initializing Blue Team Console...' -ForegroundColor DarkGray
    Write-Host ''
}

# -----------------------------------------------------------------------------
# Module manifest
# -----------------------------------------------------------------------------
$script:ModuleManifest = @(
    @{ Path = 'GhostLogger_BlueTeam.ps1'; Required = $true;  Description = 'Structured logging, baselines, monitoring' },
    @{ Path = 'env_audit.ps1';            Required = $false; Description = 'Environment and baseline checks' },
    @{ Path = 'edraudit.ps1';             Required = $false; Description = 'EDR/AV posture assessment' },
    @{ Path = 'threat_hunt.ps1';          Required = $false; Description = 'Threat hunting and anomaly review' },
    @{ Path = 'PersistenceAudit.ps1';     Required = $false; Description = 'Persistence enumeration' },
    @{ Path = 'memory_triage.ps1';        Required = $false; Description = 'Memory triage and browser audit' },
    @{ Path = 'network_audit.ps1';        Required = $false; Description = 'Network discovery and connection review' },
    @{ Path = 'artifact_collector.ps1';   Required = $false; Description = 'Artifact and evidence collection' },
    @{ Path = 'containment.ps1';          Required = $false; Description = 'Host isolation and blocking actions' },
    @{ Path = 'remediation.ps1';          Required = $false; Description = 'Cleanup and recovery actions' },
    @{ Path = 'evidence_seal.ps1';        Required = $false; Description = 'Hashing, manifest, archive' },
    @{ Path = 'reporting.ps1';            Required = $false; Description = 'Reports and dashboard' },
    @{ Path = 'compliance_guard.ps1';     Required = $false; Description = 'Safety gates and approval checks' }
)

# -----------------------------------------------------------------------------
# Utility helpers
# -----------------------------------------------------------------------------
function Test-ModulePath {
    param([string]$RelativePath)
    $fullPath = Join-Path $script:BaseDir $RelativePath
    return [pscustomobject]@{
        Exists = (Test-Path $fullPath)
        FullPath = $fullPath
    }
}

function Import-GhostModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$RelativePath,
        [switch]$Required
    )

    $pathInfo = Test-ModulePath -RelativePath $RelativePath
    if (-not $pathInfo.Exists) {
        if ($Required) {
            throw "Required module not found: $RelativePath"
        }
        return $false
    }

    try {
        $moduleName = "GhostShield.$([System.IO.Path]::GetFileNameWithoutExtension($RelativePath))"
        $moduleText = Get-Content -LiteralPath $pathInfo.FullPath -Raw -ErrorAction Stop

        if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
            Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
        }

        New-Module -Name $moduleName -ScriptBlock ([scriptblock]::Create($moduleText)) | Import-Module -Force -ErrorAction Stop
        $script:LoadedModules += $RelativePath
        Write-Host "  [+] $RelativePath" -ForegroundColor Green
        return $true
    } catch {
        $script:FailedModules += $RelativePath
        Write-Host "  [!] $RelativePath - Load error" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
        if ($Required) {
            throw
        }
        return $false
    }
}

function Load-GhostModules {
    Write-Host '[*] Loading modules...' -ForegroundColor DarkGray
    foreach ($mod in $script:ModuleManifest) {
        try {
            $loaded = Import-GhostModule -RelativePath $mod.Path -Required:$mod.Required
            if (-not $loaded -and -not $mod.Required) {
                Write-Host "  [-] $($mod.Path) - Optional, skipped" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  [X] $($mod.Path) - REQUIRED, FAILED" -ForegroundColor Red
            throw
        }
    }

    Write-Host ''
    Write-Host "[i] Loaded: $($script:LoadedModules.Count)/$($script:ModuleManifest.Count) modules" -ForegroundColor Cyan
}

function Require-Function {
    param([string]$Name)
    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required function not available: $Name"
    }
}

function Test-DestructiveActionAllowed {
    param([string]$ActionName)

    if ($script:Mode -eq 'Audit') {
        Write-Warning "$ActionName is not allowed in Audit mode. Switch to Response mode first."
        return $false
    }

    $confirm = Read-Host "Confirm action '$ActionName' (type YES to continue)"
    return ($confirm -eq 'YES')
}

# -----------------------------------------------------------------------------
# Session / logger setup
# -----------------------------------------------------------------------------
function Initialize-Session {
    $caseInput = Read-Host 'Enter Case ID (or press Enter for auto-generate)'

    Require-Function -Name 'Initialize-GhostLogger'
    Initialize-GhostLogger -CaseId $caseInput -PollSeconds 60

    $status = Get-GhostLoggerStatus
    $script:CaseId = $status.CaseId

    Write-Host "[+] Session initialized: $($script:CaseId)" -ForegroundColor Green
    Write-Host ''

    Write-GhostLog -Level INFO -Component Bootstrap -Message 'Session initialized' -Data @{
        caseId = $script:CaseId
        isAdmin = $script:IsAdmin
        mode = $script:Mode
        whatIf = $script:WhatIfMode
    }
}

# -----------------------------------------------------------------------------
# Environment assessment
# -----------------------------------------------------------------------------
function Show-EnvironmentSummary {
    Write-Host '[*] Assessing environment...' -ForegroundColor DarkGray

    $envInfo = [ordered]@{
        IsAdmin = $script:IsAdmin
        OS = [System.Environment]::OSVersion.VersionString
        Hostname = $env:COMPUTERNAME
        User = $env:USERNAME
        Domain = $env:USERDOMAIN
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

    Write-Host "  [i] Host: $($envInfo.Hostname) | User: $($envInfo.User)" -ForegroundColor DarkGray
    Write-Host "  [i] PowerShell: $($envInfo.PowerShellVersion)" -ForegroundColor DarkGray

    if (Get-Command -Name Write-GhostLog -ErrorAction SilentlyContinue) {
        Write-GhostLog -Level INFO -Component Bootstrap -Message 'Environment assessed' -Data $envInfo
    }
}

# -----------------------------------------------------------------------------
# Menu
# -----------------------------------------------------------------------------
function Show-OperatorMenu {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║              GhostShield Blue Team Console                  ║' -ForegroundColor Cyan
    Write-Host '╠══════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  [1]  Quick Host Triage                                     ║' -ForegroundColor White
    Write-Host '║  [2]  Deep Artifact Collection                              ║' -ForegroundColor White
    Write-Host '║  [3]  EDR / AV / Defender Status Check                      ║' -ForegroundColor White
    Write-Host '║  [4]  Threat Hunt: Suspicious Processes                     ║' -ForegroundColor White
    Write-Host '║  [5]  Persistence Audit                                     ║' -ForegroundColor White
    Write-Host '║  [6]  Memory Triage Summary                                 ║' -ForegroundColor White
    Write-Host '║  [7]  Browser Extension / Policy Audit                      ║' -ForegroundColor White
    Write-Host '║  [8]  Network Discovery / Connection Review                 ║' -ForegroundColor White
    Write-Host '║  [9]  Create / Refresh Baseline                             ║' -ForegroundColor White
    Write-Host '║  [10] Start Continuous Monitoring                           ║' -ForegroundColor White
    Write-Host '║  [11] Stop Continuous Monitoring                            ║' -ForegroundColor White
    Write-Host '║  [12] Isolate Host                                          ║' -ForegroundColor Yellow
    Write-Host '║  [13] Quarantine Suspicious File                            ║' -ForegroundColor Yellow
    Write-Host '║  [14] Disable Suspicious Persistence Item                   ║' -ForegroundColor Yellow
    Write-Host '║  [15] Run Guided Remediation                                ║' -ForegroundColor Green
    Write-Host '║  [16] Export IR Report Bundle                               ║' -ForegroundColor Green
    Write-Host '║  [17] Evidence Seal / Hash Archive                          ║' -ForegroundColor Green
    Write-Host '║  [18] Status Dashboard                                      ║' -ForegroundColor White
    Write-Host '║  [19] Switch Mode (Audit / Response)                        ║' -ForegroundColor White
    Write-Host '║  [20] Exit                                                  ║' -ForegroundColor DarkGray
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''
    if ($script:CaseId) {
        Write-Host "  [Case: $($script:CaseId)] [Mode: $($script:Mode)] [WhatIf: $($script:WhatIfMode)]" -ForegroundColor DarkGray
    }
}

# -----------------------------------------------------------------------------
# Action handlers
# -----------------------------------------------------------------------------
function Invoke-QuickHostTriage {
    Write-Host '[*] Running quick host triage...' -ForegroundColor Cyan
    Write-GhostLog -Level INFO -Component Triage -Message 'Quick host triage started'

    if (Get-Command -Name Get-SignedInUsersSnapshot -ErrorAction SilentlyContinue) {
        $users = Get-SignedInUsersSnapshot
        Write-Host "[+] Signed-in user snapshot collected: $($users.Count) entries" -ForegroundColor Green
        Write-GhostLog -Level INFO -Component Triage -Message 'Signed-in user snapshot collected' -Data @{ count = $users.Count; users = $users }
    }

    if (Get-Command -Name Get-EDRPresence -ErrorAction SilentlyContinue) {
        $edr = Get-EDRPresence
        Write-GhostLog -Level INFO -Component Triage -Message 'EDR presence assessed' -Data @{ edr = $edr }
    }

    if (Get-Command -Name Start-ThreatHunt -ErrorAction SilentlyContinue) {
        $sus = Start-ThreatHunt -Quick
        Write-GhostLog -Level INFO -Component Triage -Message 'Quick threat hunt completed' -Data @{ findings = $sus }
    }
}

function Invoke-DeepArtifactCollection {
    Write-Host '[*] Running deep artifact collection...' -ForegroundColor Cyan
    if (Get-Command -Name Start-ArtifactCollection -ErrorAction SilentlyContinue) {
        $result = Start-ArtifactCollection -Full
        if ($result -and $result.Count) { $script:EvidenceCount = $result.Count }
        Write-GhostLog -Level INFO -Component Collection -Message 'Deep artifact collection completed' -Data @{ result = $result }
    } else {
        Write-Warning 'ArtifactCollector module not loaded'
    }
}

function Invoke-EDRCheck {
    Write-Host '[*] Checking EDR / AV / Defender status...' -ForegroundColor Cyan
    if (Get-Command -Name Get-EDRPresence -ErrorAction SilentlyContinue) {
        $edr = Get-EDRPresence
        Write-GhostLog -Level INFO -Component EDRAudit -Message 'EDR status collected' -Data @{ edr = $edr }
    }
    if (Get-Command -Name Get-AVStatus -ErrorAction SilentlyContinue) {
        $av = Get-AVStatus
        Write-GhostLog -Level INFO -Component EDRAudit -Message 'AV status collected' -Data @{ av = $av }
    }
    if (Get-Command -Name Get-DefenderStatus -ErrorAction SilentlyContinue) {
        $def = Get-DefenderStatus
        Write-GhostLog -Level INFO -Component EDRAudit -Message 'Defender status collected' -Data @{ defender = $def }
    }
}

function Invoke-ThreatHunt {
    Write-Host '[*] Running threat hunt...' -ForegroundColor Cyan
    if (Get-Command -Name Start-ThreatHunt -ErrorAction SilentlyContinue) {
        $hunt = Start-ThreatHunt
        Write-GhostLog -Level INFO -Component ThreatHunt -Message 'Threat hunt completed' -Data @{ result = $hunt }
    } else {
        Write-Warning 'ThreatHunt module not loaded'
    }
}

function Invoke-PersistenceAudit {
    Write-Host '[*] Running persistence audit...' -ForegroundColor Cyan
    if (Get-Command -Name Get-PersistenceFindings -ErrorAction SilentlyContinue) {
        $findings = Get-PersistenceFindings
        Write-GhostLog -Level INFO -Component PersistenceAudit -Message 'Persistence audit completed' -Data @{ findings = $findings }
    } else {
        Write-Warning 'PersistenceAudit module not loaded'
    }
}

function Invoke-MemoryTriage {
    Write-Host '[*] Running memory triage...' -ForegroundColor Cyan
    if (Get-Command -Name Start-MemoryTriage -ErrorAction SilentlyContinue) {
        $summary = Start-MemoryTriage
        Write-GhostLog -Level INFO -Component MemoryTriage -Message 'Memory triage completed' -Data @{ summary = $summary }
    } else {
        Write-Warning 'MemoryTriage module not loaded'
    }
}

function Invoke-BrowserAudit {
    Write-Host '[*] Running browser audit...' -ForegroundColor Cyan
    if (Get-Command -Name Get-BrowserArtifactSummary -ErrorAction SilentlyContinue) {
        $summary = Get-BrowserArtifactSummary
        Write-GhostLog -Level INFO -Component BrowserAudit -Message 'Browser audit completed' -Data @{ summary = $summary }
    } else {
        Write-Warning 'BrowserAudit module not loaded'
    }
}

function Invoke-NetworkAudit {
    Write-Host '[*] Running network discovery / connection review...' -ForegroundColor Cyan
    if (Get-Command -Name Get-NetworkConnectionsAudit -ErrorAction SilentlyContinue) {
        $connections = Get-NetworkConnectionsAudit
        Write-GhostLog -Level INFO -Component NetworkAudit -Message 'Connection audit completed' -Data @{ result = $connections }
    }
    if (Get-Command -Name Invoke-NetworkDiscovery -ErrorAction SilentlyContinue) {
        $discovery = Invoke-NetworkDiscovery
        Write-GhostLog -Level INFO -Component NetworkAudit -Message 'Network discovery completed' -Data @{ result = $discovery }
    }
}

function Invoke-CreateOrRefreshBaseline {
    Write-Host '[*] Creating / refreshing baseline...' -ForegroundColor Cyan
    Require-Function -Name 'Get-SystemChangeSnapshot'
    Require-Function -Name 'Save-GhostBaseline'

    $snapshot = Get-SystemChangeSnapshot
    Save-GhostBaseline -Snapshot $snapshot
    Write-Host '[+] Baseline saved' -ForegroundColor Green
}

function Invoke-StartContinuousMonitoring {
    Write-Host '[*] Starting continuous monitoring...' -ForegroundColor Cyan
    Require-Function -Name 'Start-GhostMonitoring'
    Start-GhostMonitoring -PollSeconds 60
}

function Invoke-StopContinuousMonitoring {
    Write-Host '[*] Stopping continuous monitoring...' -ForegroundColor Cyan
    Require-Function -Name 'Stop-GhostMonitoring'
    Stop-GhostMonitoring
}

function Invoke-IsolateHost {
    if (-not (Test-DestructiveActionAllowed -ActionName 'IsolateHost')) { return }

    Write-Host '[*] Isolating host...' -ForegroundColor Yellow
    if (Get-Command -Name Start-HostIsolation -ErrorAction SilentlyContinue) {
        $script:ContainmentState = 'Isolated'
        $result = Start-HostIsolation -WhatIf:$script:WhatIfMode
        Write-GhostLog -Level WARN -Component Containment -Message 'Host isolation executed' -Data @{ result = $result; whatIf = $script:WhatIfMode }
    } else {
        Write-Warning 'Containment module not loaded'
    }
}

function Invoke-QuarantineFile {
    if (-not (Test-DestructiveActionAllowed -ActionName 'QuarantineFile')) { return }

    if (-not (Get-Command -Name Quarantine-File -ErrorAction SilentlyContinue)) {
        Write-Warning 'Remediation module not loaded'
        return
    }

    $path = Read-Host 'Enter suspicious file path'
    if (-not $path) { return }

    $result = Quarantine-File -Path $path -WhatIf:$script:WhatIfMode
    Write-GhostLog -Level WARN -Component Remediation -Message 'Quarantine action executed' -Data @{ path = $path; result = $result; whatIf = $script:WhatIfMode }
}

function Invoke-DisablePersistenceItem {
    if (-not (Test-DestructiveActionAllowed -ActionName 'DisablePersistenceItem')) { return }

    if (-not (Get-Command -Name Remove-PersistenceItem -ErrorAction SilentlyContinue)) {
        Write-Warning 'Remediation module not loaded'
        return
    }

    $identifier = Read-Host 'Enter persistence item identifier / path'
    if (-not $identifier) { return }

    $result = Remove-PersistenceItem -Identifier $identifier -WhatIf:$script:WhatIfMode
    Write-GhostLog -Level WARN -Component Remediation -Message 'Persistence item removal executed' -Data @{ identifier = $identifier; result = $result; whatIf = $script:WhatIfMode }
}

function Invoke-GuidedRemediation {
    if (-not (Test-DestructiveActionAllowed -ActionName 'GuidedRemediation')) { return }

    Write-Host '[*] Running guided remediation...' -ForegroundColor Green
    if (Get-Command -Name Start-Remediation -ErrorAction SilentlyContinue) {
        $result = Start-Remediation -WhatIf:$script:WhatIfMode
        Write-GhostLog -Level WARN -Component Remediation -Message 'Guided remediation executed' -Data @{ result = $result; whatIf = $script:WhatIfMode }
    } else {
        Write-Warning 'Remediation module not loaded'
    }
}

function Invoke-ExportIRBundle {
    Write-Host '[*] Exporting IR bundle...' -ForegroundColor Green
    if (Get-Command -Name New-IncidentReport -ErrorAction SilentlyContinue) {
        $report = New-IncidentReport -CaseId $script:CaseId
        Write-GhostLog -Level INFO -Component Reporting -Message 'IR report bundle exported' -Data @{ result = $report }
    } else {
        Write-Warning 'Reporting module not loaded'
    }
}

function Invoke-EvidenceSeal {
    Write-Host '[*] Sealing evidence...' -ForegroundColor Green
    if (Get-Command -Name Protect-EvidenceBundle -ErrorAction SilentlyContinue) {
        $result = Protect-EvidenceBundle -CaseId $script:CaseId
        Write-GhostLog -Level INFO -Component Evidence -Message 'Evidence bundle sealed' -Data @{ result = $result }
    } else {
        Write-Warning 'EvidenceSeal module not loaded'
    }
}

function Show-StatusDashboard {
    Write-Host ''
    Write-Host '═══════════════ GHOSTSHIELD STATUS DASHBOARD ═══════════════' -ForegroundColor Cyan
    Write-Host "Case ID:           $($script:CaseId)"
    Write-Host "Operator:          $env:USERNAME"
    Write-Host "Hostname:          $env:COMPUTERNAME"
    Write-Host "Session Minutes:   $([math]::Round(((Get-Date) - $script:SessionStart).TotalMinutes, 1))"
    Write-Host "Admin Mode:        $($script:IsAdmin)"
    Write-Host "Mode:              $($script:Mode)"
    Write-Host "WhatIf:            $($script:WhatIfMode)"
    Write-Host "Modules Loaded:    $($script:LoadedModules.Count)"
    Write-Host "Modules Failed:    $($script:FailedModules.Count)"
    Write-Host "Containment State: $($script:ContainmentState)"
    Write-Host "Evidence Items:    $($script:EvidenceCount)"
    Write-Host "High Findings:     $($script:HighSeverityCount)"

    if (Get-Command -Name Get-GhostLoggerStatus -ErrorAction SilentlyContinue) {
        $loggerStatus = Get-GhostLoggerStatus
        Write-Host "Json Log:          $($loggerStatus.JsonLogPath)"
        Write-Host "Baseline:          $($loggerStatus.BaselinePath)"
        Write-Host "Monitoring:        $($loggerStatus.Monitoring)"
    }

    Write-Host '════════════════════════════════════════════════════════════' -ForegroundColor Cyan
}

function Invoke-SwitchMode {
    Write-Host "Current mode: $($script:Mode)" -ForegroundColor DarkGray
    Write-Host '  [1] Audit (non-destructive)' -ForegroundColor White
    Write-Host '  [2] Response (containment/remediation allowed with confirmation)' -ForegroundColor White
    $choice = Read-Host 'Select mode'
    switch ($choice) {
        '1' { $script:Mode = 'Audit' }
        '2' { $script:Mode = 'Response' }
        default { Write-Warning 'Invalid selection'; return }
    }
    Write-GhostLog -Level INFO -Component Bootstrap -Message 'Mode changed' -Data @{ mode = $script:Mode }
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
function Start-GhostShieldConsole {
    Show-Banner

    if (-not $script:IsAdmin) {
        Write-Warning '[!] Admin rights are recommended. Some defensive actions may be limited.'
        Write-Host '[i] Relaunch as Administrator for full triage and containment functionality.' -ForegroundColor Yellow
    }

    Load-GhostModules
    Initialize-Session
    Show-EnvironmentSummary

    while ($true) {
        Show-OperatorMenu
        $choice = Read-Host 'Select operation'

        switch ($choice) {
            '1'  { Invoke-QuickHostTriage }
            '2'  { Invoke-DeepArtifactCollection }
            '3'  { Invoke-EDRCheck }
            '4'  { Invoke-ThreatHunt }
            '5'  { Invoke-PersistenceAudit }
            '6'  { Invoke-MemoryTriage }
            '7'  { Invoke-BrowserAudit }
            '8'  { Invoke-NetworkAudit }
            '9'  { Invoke-CreateOrRefreshBaseline }
            '10' { Invoke-StartContinuousMonitoring }
            '11' { Invoke-StopContinuousMonitoring }
            '12' { Invoke-IsolateHost }
            '13' { Invoke-QuarantineFile }
            '14' { Invoke-DisablePersistenceItem }
            '15' { Invoke-GuidedRemediation }
            '16' { Invoke-ExportIRBundle }
            '17' { Invoke-EvidenceSeal }
            '18' { Show-StatusDashboard }
            '19' { Invoke-SwitchMode }
            '20' {
                Write-Host '[✖] Cleaning up session...' -ForegroundColor Gray
                if (Get-Command -Name Stop-GhostMonitoring -ErrorAction SilentlyContinue) {
                    Stop-GhostMonitoring
                }
                if (Get-Command -Name Stop-GhostLogger -ErrorAction SilentlyContinue) {
                    Stop-GhostLogger
                }
                Write-Host "[~] GhostShield session ended. Duration: $([math]::Round(((Get-Date) - $script:SessionStart).TotalMinutes, 1)) minutes" -ForegroundColor DarkGray
                break
            }
            default {
                Write-Warning 'Invalid selection'
            }
        }

        Write-Host ''
        Read-Host 'Press Enter to continue'
    }
}

Start-GhostShieldConsole
