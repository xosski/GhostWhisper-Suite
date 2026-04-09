Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
ArtifactCollector.ps1
Blue-team artifact collection module.

Purpose
- Collect common host triage artifacts into a case folder
- Export structured JSON snapshots plus selected raw text/log artifacts
- Build a simple manifest that can be handed to EvidenceSeal / Reporting

Design goals
- Defensive and auditable
- No destructive actions
- Reasonable defaults with optional deeper collection
#>

$script:ArtifactCollectorState = [ordered]@{
    CaseId = $null
    OutputRoot = Join-Path $env:ProgramData 'GhostShield\Cases'
    CurrentCaseDir = $null
    Manifest = New-Object System.Collections.Generic.List[object]
}

function New-ArtifactCaseDirectory {
    [CmdletBinding()]
    param(
        [string]$CaseId
    )

    if (-not $CaseId) {
        $CaseId = "CASE-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }

    $caseDir = Join-Path $script:ArtifactCollectorState.OutputRoot $CaseId
    $folders = @(
        $caseDir,
        (Join-Path $caseDir 'Host'),
        (Join-Path $caseDir 'Network'),
        (Join-Path $caseDir 'Persistence'),
        (Join-Path $caseDir 'Browser'),
        (Join-Path $caseDir 'Logs'),
        (Join-Path $caseDir 'Raw'),
        (Join-Path $caseDir 'Memory')
    )

    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $script:ArtifactCollectorState.CaseId = $CaseId
    $script:ArtifactCollectorState.CurrentCaseDir = $caseDir
    $script:ArtifactCollectorState.Manifest.Clear()

    return $caseDir
}

function Add-ArtifactManifestEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Path,
        [string]$CollectionMethod = 'json-export',
        [hashtable]$Metadata = @{}
    )

    $entry = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Category = $Category
        Name = $Name
        Path = $Path
        CollectionMethod = $CollectionMethod
        Metadata = $Metadata
    }
    $script:ArtifactCollectorState.Manifest.Add($entry) | Out-Null
    return $entry
}

function Export-ArtifactJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] $Data
    )

    $targetDir = Join-Path $script:ArtifactCollectorState.CurrentCaseDir $Category
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    $path = Join-Path $targetDir ("{0}.json" -f $Name)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Force -Encoding UTF8
    Add-ArtifactManifestEntry -Category $Category -Name $Name -Path $path -CollectionMethod 'json-export' -Metadata @{ itemCount = @($Data).Count }
    return $path
}

function Export-ArtifactText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string[]]$Lines
    )

    $targetDir = Join-Path $script:ArtifactCollectorState.CurrentCaseDir $Category
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    $path = Join-Path $targetDir ("{0}.txt" -f $Name)
    $Lines | Set-Content -Path $path -Force -Encoding UTF8
    Add-ArtifactManifestEntry -Category $Category -Name $Name -Path $path -CollectionMethod 'text-export' -Metadata @{ lineCount = @($Lines).Count }
    return $path
}

function Copy-ArtifactFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$SourcePath,
        [string]$DestinationName
    )

    if (-not (Test-Path $SourcePath)) {
        return $null
    }

    $targetDir = Join-Path $script:ArtifactCollectorState.CurrentCaseDir $Category
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    if (-not $DestinationName) {
        $DestinationName = Split-Path $SourcePath -Leaf
    }

    $dest = Join-Path $targetDir $DestinationName
    Copy-Item -Path $SourcePath -Destination $dest -Force
    Add-ArtifactManifestEntry -Category $Category -Name $DestinationName -Path $dest -CollectionMethod 'file-copy' -Metadata @{ source = $SourcePath }
    return $dest
}

function Get-HostSnapshot {
    [CmdletBinding()]
    param()

    $snapshot = [ordered]@{}

    try {
        $snapshot.ComputerInfo = Get-ComputerInfo | Select-Object *
    } catch {
        $snapshot.ComputerInfo = [ordered]@{ Error = $_.Exception.Message }
    }

    try {
        $snapshot.OS = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, InstallDate, LastBootUpTime, CSName
    } catch {
        $snapshot.OS = [ordered]@{ Error = $_.Exception.Message }
    }

    try {
        $snapshot.Processes = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine, CreationDate
    } catch {
        $snapshot.Processes = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        $snapshot.Services = Get-CimInstance Win32_Service | Select-Object Name, DisplayName, State, StartMode, StartName, PathName
    } catch {
        $snapshot.Services = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        $snapshot.ScheduledTasks = Get-ScheduledTask | Select-Object TaskName, TaskPath, State, Author, URI
    } catch {
        $snapshot.ScheduledTasks = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
            $snapshot.LocalUsers = Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordRequired, PasswordExpires
        }
    } catch {
        $snapshot.LocalUsers = @([ordered]@{ Error = $_.Exception.Message })
    }

    return [pscustomobject]$snapshot
}

function Get-NetworkSnapshot {
    [CmdletBinding()]
    param()

    $snapshot = [ordered]@{}

    try {
        if (Get-Command Get-NetworkConnectionsAudit -ErrorAction SilentlyContinue) {
            $snapshot.Connections = Get-NetworkConnectionsAudit
        } else {
            $snapshot.Connections = Get-NetTCPConnection | Select-Object State, LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess
        }
    } catch {
        $snapshot.Connections = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        if (Get-Command Get-ListenerAudit -ErrorAction SilentlyContinue) {
            $snapshot.ListenerFindings = Get-ListenerAudit
        }
    } catch {
        $snapshot.ListenerFindings = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        if (Get-Command Get-DnsCacheAudit -ErrorAction SilentlyContinue) {
            $snapshot.DnsCache = Get-DnsCacheAudit
        }
    } catch {
        $snapshot.DnsCache = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        if (Get-Command Get-ArpNeighborAudit -ErrorAction SilentlyContinue) {
            $snapshot.Neighbors = Get-ArpNeighborAudit
        }
    } catch {
        $snapshot.Neighbors = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        if (Get-Command Get-FirewallProfileAudit -ErrorAction SilentlyContinue) {
            $snapshot.FirewallProfiles = Get-FirewallProfileAudit
        }
    } catch {
        $snapshot.FirewallProfiles = @([ordered]@{ Error = $_.Exception.Message })
    }

    try {
        if (Get-Command Get-NetworkInterfaceAudit -ErrorAction SilentlyContinue) {
            $snapshot.Interfaces = Get-NetworkInterfaceAudit
        }
    } catch {
        $snapshot.Interfaces = [ordered]@{ Error = $_.Exception.Message }
    }

    return [pscustomobject]$snapshot
}

function Get-PersistenceSnapshot {
    [CmdletBinding()]
    param(
        [switch]$Quick
    )

    try {
        if (Get-Command Get-PersistenceFindings -ErrorAction SilentlyContinue) {
            return [pscustomobject]@{
                Findings = Get-PersistenceFindings -Quick:$Quick
                Summary = if (Get-Command Get-PersistenceSummary -ErrorAction SilentlyContinue) { Get-PersistenceSummary } else { $null }
            }
        }
    } catch {
        return [pscustomobject]@{ Error = $_.Exception.Message }
    }

    return [pscustomobject]@{ Findings = @(); Summary = $null }
}

function Get-BrowserSnapshot {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-BrowserArtifactSummary -ErrorAction SilentlyContinue) {
            return Get-BrowserArtifactSummary
        }
    } catch {
        return [pscustomobject]@{ Error = $_.Exception.Message }
    }

    return [pscustomobject]@{ Findings = @() }
}

function Get-MemorySnapshot {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Start-MemoryTriage -ErrorAction SilentlyContinue) {
            return Start-MemoryTriage -IncludeBrowserChecks:$false
        }
    } catch {
        return [pscustomobject]@{ Error = $_.Exception.Message }
    }

    return [pscustomobject]@{ Findings = @() }
}

function Export-BasicEventLogs {
    [CmdletBinding()]
    param(
        [int]$MaxEvents = 500
    )

    $logTargets = @('System','Application','Security','Windows PowerShell')
    $exported = @()

    foreach ($logName in $logTargets) {
        try {
            $events = Get-WinEvent -LogName $logName -MaxEvents $MaxEvents -ErrorAction Stop |
                Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, MachineName, Message
            $path = Export-ArtifactJson -Category 'Logs' -Name ($logName -replace '[^A-Za-z0-9_-]','_') -Data $events
            $exported += $path
        } catch {
            $exported += (Export-ArtifactJson -Category 'Logs' -Name ($logName -replace '[^A-Za-z0-9_-]','_') -Data @([ordered]@{ Error = $_.Exception.Message }))
        }
    }

    return $exported
}

function Copy-OptionalRawArtifacts {
    [CmdletBinding()]
    param()

    $copied = @()
    $candidates = @(
        "$env:WINDIR\System32\drivers\etc\hosts",
        "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    )

    foreach ($candidate in $candidates) {
        $copiedPath = Copy-ArtifactFile -Category 'Raw' -SourcePath $candidate
        if ($copiedPath) { $copied += $copiedPath }
    }

    return $copied
}

function Export-Manifest {
    [CmdletBinding()]
    param()

    $path = Join-Path $script:ArtifactCollectorState.CurrentCaseDir 'manifest.json'
    $manifestObject = [pscustomobject]@{
        CaseId = $script:ArtifactCollectorState.CaseId
        CollectedAt = (Get-Date).ToString('o')
        Hostname = $env:COMPUTERNAME
        Operator = $env:USERNAME
        Items = @($script:ArtifactCollectorState.Manifest)
    }
    $manifestObject | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Force -Encoding UTF8
    return $path
}

function Start-ArtifactCollection {
    [CmdletBinding()]
    param(
        [switch]$Full,
        [string]$CaseId
    )

    $caseDir = New-ArtifactCaseDirectory -CaseId $CaseId

    $hostSnapshot = Get-HostSnapshot
    $networkSnapshot = Get-NetworkSnapshot
    $persistenceSnapshot = Get-PersistenceSnapshot -Quick:(-not $Full)
    $browserSnapshot = Get-BrowserSnapshot
    $memorySnapshot = Get-MemorySnapshot

    $null = Export-ArtifactJson -Category 'Host' -Name 'host_snapshot' -Data $hostSnapshot
    $null = Export-ArtifactJson -Category 'Network' -Name 'network_snapshot' -Data $networkSnapshot
    $null = Export-ArtifactJson -Category 'Persistence' -Name 'persistence_snapshot' -Data $persistenceSnapshot
    $null = Export-ArtifactJson -Category 'Browser' -Name 'browser_snapshot' -Data $browserSnapshot
    $null = Export-ArtifactJson -Category 'Memory' -Name 'memory_snapshot' -Data $memorySnapshot

    $null = Export-BasicEventLogs -MaxEvents ($(if ($Full) { 1000 } else { 250 }))
    $null = Copy-OptionalRawArtifacts

    if ($Full) {
        try {
            $drivers = Get-CimInstance Win32_SystemDriver | Select-Object Name, State, StartMode, PathName
            $null = Export-ArtifactJson -Category 'Host' -Name 'drivers' -Data $drivers
        } catch {}

        try {
            $hotfixes = Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy
            $null = Export-ArtifactJson -Category 'Host' -Name 'hotfixes' -Data $hotfixes
        } catch {}

        try {
            $shares = Get-SmbShare | Select-Object Name, Path, Description, CurrentUsers, ShareState
            $null = Export-ArtifactJson -Category 'Host' -Name 'shares' -Data $shares
        } catch {}
    }

    $manifestPath = Export-Manifest

    return [pscustomobject]@{
        CaseId = $script:ArtifactCollectorState.CaseId
        CaseDirectory = $caseDir
        ManifestPath = $manifestPath
        Count = @($script:ArtifactCollectorState.Manifest).Count
        Items = @($script:ArtifactCollectorState.Manifest)
    }
}

function Export-IRBundle {
    [CmdletBinding()]
    param(
        [string]$CaseId
    )

    return Start-ArtifactCollection -Full -CaseId $CaseId
}

Export-ModuleMember -Function @(
    'New-ArtifactCaseDirectory',
    'Add-ArtifactManifestEntry',
    'Export-ArtifactJson',
    'Export-ArtifactText',
    'Copy-ArtifactFile',
    'Get-HostSnapshot',
    'Get-NetworkSnapshot',
    'Get-PersistenceSnapshot',
    'Get-BrowserSnapshot',
    'Get-MemorySnapshot',
    'Export-BasicEventLogs',
    'Copy-OptionalRawArtifacts',
    'Export-Manifest',
    'Start-ArtifactCollection',
    'Export-IRBundle'
)
