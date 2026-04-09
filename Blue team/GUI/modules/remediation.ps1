Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Remediation.ps1
Blue-team remediation module.

Purpose
- Perform guided, auditable cleanup actions after triage/containment
- Quarantine suspicious files safely
- Remove or disable common persistence mechanisms
- Remove suspicious browser extensions and restore safer browser defaults
- Return structured results for GhostShield logging and reporting

Safety notes
- Defensive only
- Supports -WhatIf through SupportsShouldProcess where applicable
- Prefers quarantine / disable / backup over destructive deletion
#>

$script:RemediationState = [ordered]@{
    QuarantineRoot = Join-Path $env:ProgramData 'GhostShield\Quarantine'
    BackupRoot = Join-Path $env:ProgramData 'GhostShield\Backups'
    Findings = New-Object System.Collections.Generic.List[object]
}

function New-RemediationResult {
    param(
        [string]$Action,
        [string]$Status,
        [string]$Target,
        [string]$Message,
        [hashtable]$Details = @{}
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Action = $Action
        Status = $Status
        Target = $Target
        Message = $Message
        Details = $Details
    }
}

function Initialize-RemediationPaths {
    [CmdletBinding()]
    param()

    New-Item -ItemType Directory -Path $script:RemediationState.QuarantineRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $script:RemediationState.BackupRoot -Force | Out-Null

    return New-RemediationResult -Action 'InitializePaths' -Status 'Success' -Target 'RemediationPaths' -Message 'Quarantine and backup paths initialized' -Details @{
        QuarantineRoot = $script:RemediationState.QuarantineRoot
        BackupRoot = $script:RemediationState.BackupRoot
    }
}

function Get-FileHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path $Path)) { return $null }

    try {
        [pscustomobject]@{
            SHA256 = (Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop).Hash
            SHA1 = (Get-FileHash -Path $Path -Algorithm SHA1 -ErrorAction Stop).Hash
            MD5 = (Get-FileHash -Path $Path -Algorithm MD5 -ErrorAction Stop).Hash
        }
    } catch {
        $null
    }
}

function Backup-Artifact {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        return New-RemediationResult -Action 'BackupArtifact' -Status 'Error' -Target $Path -Message 'Source path does not exist'
    }

    Initialize-RemediationPaths | Out-Null
    $name = if ($Label) { $Label } else { Split-Path $Path -Leaf }
    $safeName = ($name -replace '[^A-Za-z0-9._-]','_')
    $dest = Join-Path $script:RemediationState.BackupRoot ("{0}_{1}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $safeName)

    try {
        if ($PSCmdlet.ShouldProcess($Path, 'Backup artifact')) {
            if ((Get-Item $Path).PSIsContainer) {
                Copy-Item -Path $Path -Destination $dest -Recurse -Force -ErrorAction Stop
            } else {
                Copy-Item -Path $Path -Destination $dest -Force -ErrorAction Stop
            }
            return New-RemediationResult -Action 'BackupArtifact' -Status 'Success' -Target $Path -Message 'Artifact backed up' -Details @{ BackupPath = $dest }
        }
    } catch {
        return New-RemediationResult -Action 'BackupArtifact' -Status 'Error' -Target $Path -Message 'Backup failed' -Details @{ Error = $_.Exception.Message }
    }
}

function Quarantine-File {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return New-RemediationResult -Action 'QuarantineFile' -Status 'Error' -Target $Path -Message 'File does not exist'
    }

    Initialize-RemediationPaths | Out-Null
    $hashes = Get-FileHashes -Path $Path
    $safeName = ((Split-Path $Path -Leaf) -replace '[^A-Za-z0-9._-]','_')
    $dest = Join-Path $script:RemediationState.QuarantineRoot ("{0}_{1}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $safeName)

    try {
        if ($PSCmdlet.ShouldProcess($Path, 'Quarantine suspicious file')) {
            Copy-Item -Path $Path -Destination $dest -Force -ErrorAction Stop
            try {
                icacls $dest /inheritance:r /grant:r 'Administrators:F' 'SYSTEM:F' | Out-Null
            } catch {}
            try {
                attrib +R +H $dest 2>$null | Out-Null
            } catch {}
            try {
                Remove-Item -Path $Path -Force -ErrorAction Stop
            } catch {
                # Fallback: lock down original if remove fails
                try { icacls $Path /inheritance:r /grant:r 'Administrators:F' 'SYSTEM:F' | Out-Null } catch {}
            }

            return New-RemediationResult -Action 'QuarantineFile' -Status 'Success' -Target $Path -Message 'File quarantined' -Details @{
                QuarantinePath = $dest
                Hashes = $hashes
            }
        }
    } catch {
        return New-RemediationResult -Action 'QuarantineFile' -Status 'Error' -Target $Path -Message 'Quarantine failed' -Details @{ Error = $_.Exception.Message }
    }
}

function Remove-PersistenceItem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$Identifier,
        [ValidateSet('Auto','RunKey','ScheduledTask','Service','StartupFile','WMIConsumer')] [string]$Type = 'Auto'
    )

    $resolvedType = $Type
    if ($Type -eq 'Auto') {
        if ($Identifier -match '^HK(LM|CU):') { $resolvedType = 'RunKey' }
        elseif ($Identifier -match '^\\') { $resolvedType = 'ScheduledTask' }
        elseif (Test-Path $Identifier) { $resolvedType = 'StartupFile' }
        else { $resolvedType = 'Service' }
    }

    switch ($resolvedType) {
        'RunKey'      { return Remove-RunKeyPersistence -RegistryPath $Identifier }
        'ScheduledTask' { return Disable-TaskPersistence -TaskIdentifier $Identifier }
        'Service'     { return Disable-ServicePersistence -ServiceName $Identifier }
        'StartupFile' { return Remove-StartupArtifact -Path $Identifier }
        'WMIConsumer' { return Remove-WMIConsumerPersistence -Name $Identifier }
    }
}

function Remove-RunKeyPersistence {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$RegistryPath
    )

    try {
        if ($RegistryPath -notmatch '^(?<Key>.+)\\(?<ValueName>[^\\]+)$') {
            return New-RemediationResult -Action 'RemoveRunKey' -Status 'Error' -Target $RegistryPath -Message 'Registry path must include value name'
        }

        $keyPath = $Matches.Key
        $valueName = $Matches.ValueName
        $backup = $null
        try {
            $current = Get-ItemProperty -Path $keyPath -ErrorAction Stop
            $backup = $current.$valueName
        } catch {}

        if ($PSCmdlet.ShouldProcess($RegistryPath, 'Remove autorun registry value')) {
            Remove-ItemProperty -Path $keyPath -Name $valueName -ErrorAction Stop
            return New-RemediationResult -Action 'RemoveRunKey' -Status 'Success' -Target $RegistryPath -Message 'Autorun registry value removed' -Details @{ PreviousValue = $backup }
        }
    } catch {
        return New-RemediationResult -Action 'RemoveRunKey' -Status 'Error' -Target $RegistryPath -Message 'Failed to remove autorun value' -Details @{ Error = $_.Exception.Message }
    }
}

function Disable-TaskPersistence {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$TaskIdentifier
    )

    try {
        $taskPath = '\'
        $taskName = $TaskIdentifier
        if ($TaskIdentifier -match '^(?<Path>\\.*\\)(?<Name>[^\\]+)$') {
            $taskPath = $Matches.Path
            $taskName = $Matches.Name
        }

        if ($PSCmdlet.ShouldProcess($TaskIdentifier, 'Disable scheduled task')) {
            Disable-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop | Out-Null
            return New-RemediationResult -Action 'DisableTask' -Status 'Success' -Target $TaskIdentifier -Message 'Scheduled task disabled'
        }
    } catch {
        return New-RemediationResult -Action 'DisableTask' -Status 'Error' -Target $TaskIdentifier -Message 'Failed to disable scheduled task' -Details @{ Error = $_.Exception.Message }
    }
}

function Disable-ServicePersistence {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$ServiceName,
        [switch]$StopIfRunning = $true
    )

    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($PSCmdlet.ShouldProcess($ServiceName, 'Disable service persistence')) {
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            if ($StopIfRunning -and $svc.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            }
            return New-RemediationResult -Action 'DisableService' -Status 'Success' -Target $ServiceName -Message 'Service disabled' -Details @{ StopIfRunning = [bool]$StopIfRunning }
        }
    } catch {
        return New-RemediationResult -Action 'DisableService' -Status 'Error' -Target $ServiceName -Message 'Failed to disable service' -Details @{ Error = $_.Exception.Message }
    }
}

function Remove-StartupArtifact {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return New-RemediationResult -Action 'RemoveStartupArtifact' -Status 'Error' -Target $Path -Message 'Startup artifact path does not exist'
    }

    $backupResult = Backup-Artifact -Path $Path -Label 'startup_artifact' -WhatIf:$WhatIfPreference
    try {
        if ($PSCmdlet.ShouldProcess($Path, 'Remove startup artifact')) {
            Remove-Item -Path $Path -Force -Recurse -ErrorAction Stop
            return New-RemediationResult -Action 'RemoveStartupArtifact' -Status 'Success' -Target $Path -Message 'Startup artifact removed' -Details @{ Backup = $backupResult.Details.BackupPath }
        }
    } catch {
        return New-RemediationResult -Action 'RemoveStartupArtifact' -Status 'Error' -Target $Path -Message 'Failed to remove startup artifact' -Details @{ Error = $_.Exception.Message; Backup = $backupResult.Details.BackupPath }
    }
}

function Remove-WMIConsumerPersistence {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$Name
    )

    try {
        $consumer = Get-WmiObject -Namespace 'root\subscription' -Class CommandLineEventConsumer -Filter "Name='$Name'" -ErrorAction Stop
        if ($PSCmdlet.ShouldProcess($Name, 'Remove WMI event consumer')) {
            $consumer.Delete() | Out-Null
            return New-RemediationResult -Action 'RemoveWMIConsumer' -Status 'Success' -Target $Name -Message 'WMI command-line event consumer removed'
        }
    } catch {
        return New-RemediationResult -Action 'RemoveWMIConsumer' -Status 'Error' -Target $Name -Message 'Failed to remove WMI consumer' -Details @{ Error = $_.Exception.Message }
    }
}

function Remove-SuspiciousExtension {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$ExtensionPath
    )

    if (-not (Test-Path $ExtensionPath)) {
        return New-RemediationResult -Action 'RemoveExtension' -Status 'Error' -Target $ExtensionPath -Message 'Extension path does not exist'
    }

    $backupResult = Backup-Artifact -Path $ExtensionPath -Label 'browser_extension' -WhatIf:$WhatIfPreference
    try {
        if ($PSCmdlet.ShouldProcess($ExtensionPath, 'Remove browser extension directory')) {
            Remove-Item -Path $ExtensionPath -Recurse -Force -ErrorAction Stop
            return New-RemediationResult -Action 'RemoveExtension' -Status 'Success' -Target $ExtensionPath -Message 'Browser extension removed' -Details @{ Backup = $backupResult.Details.BackupPath }
        }
    } catch {
        return New-RemediationResult -Action 'RemoveExtension' -Status 'Error' -Target $ExtensionPath -Message 'Failed to remove browser extension' -Details @{ Error = $_.Exception.Message; Backup = $backupResult.Details.BackupPath }
    }
}

function Restore-BrowserDefaults {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Chrome','Edge','Brave')] [string]$Browser
    )

    $results = @()
    $policyRoots = switch ($Browser) {
        'Chrome' { @('HKLM:\SOFTWARE\Policies\Google\Chrome','HKCU:\SOFTWARE\Policies\Google\Chrome') }
        'Edge'   { @('HKLM:\SOFTWARE\Policies\Microsoft\Edge','HKCU:\SOFTWARE\Policies\Microsoft\Edge') }
        'Brave'  { @('HKLM:\SOFTWARE\Policies\BraveSoftware\Brave','HKCU:\SOFTWARE\Policies\BraveSoftware\Brave') }
    }

    foreach ($root in $policyRoots) {
        try {
            if (-not (Test-Path $root)) { continue }
            $backup = Backup-Artifact -Path $root -Label ("{0}_policy" -f $Browser) -WhatIf:$WhatIfPreference
            if ($PSCmdlet.ShouldProcess($root, 'Remove browser policy key')) {
                Remove-Item -Path $root -Recurse -Force -ErrorAction Stop
                $results += New-RemediationResult -Action 'RestoreBrowserDefaults' -Status 'Success' -Target $root -Message 'Browser policy key removed' -Details @{ Backup = $backup.Details.BackupPath }
            }
        } catch {
            $results += New-RemediationResult -Action 'RestoreBrowserDefaults' -Status 'Error' -Target $root -Message 'Failed to remove browser policy key' -Details @{ Error = $_.Exception.Message }
        }
    }

    return $results
}

function Start-Remediation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$SuspiciousFiles = @(),
        [string[]]$PersistenceItems = @(),
        [string[]]$ExtensionPaths = @(),
        [ValidateSet('None','Chrome','Edge','Brave','All')] [string]$BrowserReset = 'None'
    )

    $results = @()
    Initialize-RemediationPaths | Out-Null

    foreach ($file in $SuspiciousFiles) {
        $results += Quarantine-File -Path $file -WhatIf:$WhatIfPreference
    }

    foreach ($item in $PersistenceItems) {
        $results += Remove-PersistenceItem -Identifier $item -WhatIf:$WhatIfPreference
    }

    foreach ($ext in $ExtensionPaths) {
        $results += Remove-SuspiciousExtension -ExtensionPath $ext -WhatIf:$WhatIfPreference
    }

    switch ($BrowserReset) {
        'Chrome' { $results += Restore-BrowserDefaults -Browser Chrome -WhatIf:$WhatIfPreference }
        'Edge'   { $results += Restore-BrowserDefaults -Browser Edge -WhatIf:$WhatIfPreference }
        'Brave'  { $results += Restore-BrowserDefaults -Browser Brave -WhatIf:$WhatIfPreference }
        'All'    {
            $results += Restore-BrowserDefaults -Browser Chrome -WhatIf:$WhatIfPreference
            $results += Restore-BrowserDefaults -Browser Edge -WhatIf:$WhatIfPreference
            $results += Restore-BrowserDefaults -Browser Brave -WhatIf:$WhatIfPreference
        }
    }

    return [pscustomobject]@{
        TotalActions = @($results).Count
        SuccessCount = @($results | Where-Object Status -eq 'Success').Count
        ErrorCount = @($results | Where-Object Status -eq 'Error').Count
        Results = $results
    }
}

Export-ModuleMember -Function @(
    'Initialize-RemediationPaths',
    'Get-FileHashes',
    'Backup-Artifact',
    'Quarantine-File',
    'Remove-PersistenceItem',
    'Remove-RunKeyPersistence',
    'Disable-TaskPersistence',
    'Disable-ServicePersistence',
    'Remove-StartupArtifact',
    'Remove-WMIConsumerPersistence',
    'Remove-SuspiciousExtension',
    'Restore-BrowserDefaults',
    'Start-Remediation'
)
