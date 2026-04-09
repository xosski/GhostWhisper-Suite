Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
ComplianceGuard.ps1
Blue-team compliance and safety guard module.

Purpose
- Enforce operating mode and approval requirements
- Require transcript / logging readiness before sensitive actions
- Validate module trust state (signature / hash status where available)
- Provide reusable preflight checks for GhostShieldBootstrap actions

Design notes
- Defensive only
- Intended to reduce accidental misuse and improve auditability
- Works as a policy/control layer rather than a scanning or response module
#>

$script:ComplianceGuardState = [ordered]@{
    Mode = 'Audit'
    TranscriptRequired = $true
    LoggingRequired = $true
    SignatureValidationRequired = $false
    ApprovalRequiredForResponse = $true
    ApprovalRequiredForDestructive = $true
    AllowedOperators = @()
    AllowedActionsInAuditMode = @(
        'QuickHostTriage',
        'DeepArtifactCollection',
        'EDRCheck',
        'ThreatHunt',
        'PersistenceAudit',
        'MemoryTriage',
        'BrowserAudit',
        'NetworkAudit',
        'CreateOrRefreshBaseline',
        'StartContinuousMonitoring',
        'StopContinuousMonitoring',
        'ExportIRBundle',
        'EvidenceSeal',
        'StatusDashboard'
    )
    DestructiveActions = @(
        'IsolateHost',
        'QuarantineFile',
        'DisablePersistenceItem',
        'GuidedRemediation',
        'RemoveContainmentRules',
        'StopProcess',
        'SuspendProcess',
        'DisableService',
        'DisableTask',
        'RemoveExtension',
        'RestoreBrowserDefaults'
    )
    TrustedHashes = @{}
}

function New-ComplianceResult {
    param(
        [string]$Action,
        [string]$Status,
        [string]$Message,
        [hashtable]$Details = @{}
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Action = $Action
        Status = $Status
        Message = $Message
        Details = $Details
    }
}

function Set-ComplianceMode {
    [CmdletBinding()]
    param(
        [ValidateSet('Audit','Response')] [string]$Mode
    )

    $script:ComplianceGuardState.Mode = $Mode
    return New-ComplianceResult -Action 'SetMode' -Status 'Success' -Message 'Compliance mode updated' -Details @{ Mode = $Mode }
}

function Get-ComplianceMode {
    [CmdletBinding()]
    param()

    return $script:ComplianceGuardState.Mode
}

function Set-CompliancePolicy {
    [CmdletBinding()]
    param(
        [bool]$TranscriptRequired = $true,
        [bool]$LoggingRequired = $true,
        [bool]$SignatureValidationRequired = $false,
        [bool]$ApprovalRequiredForResponse = $true,
        [bool]$ApprovalRequiredForDestructive = $true,
        [string[]]$AllowedOperators = @()
    )

    $script:ComplianceGuardState.TranscriptRequired = $TranscriptRequired
    $script:ComplianceGuardState.LoggingRequired = $LoggingRequired
    $script:ComplianceGuardState.SignatureValidationRequired = $SignatureValidationRequired
    $script:ComplianceGuardState.ApprovalRequiredForResponse = $ApprovalRequiredForResponse
    $script:ComplianceGuardState.ApprovalRequiredForDestructive = $ApprovalRequiredForDestructive
    $script:ComplianceGuardState.AllowedOperators = @($AllowedOperators | Where-Object { $_ } | Sort-Object -Unique)

    return New-ComplianceResult -Action 'SetPolicy' -Status 'Success' -Message 'Compliance policy updated' -Details @{
        TranscriptRequired = $TranscriptRequired
        LoggingRequired = $LoggingRequired
        SignatureValidationRequired = $SignatureValidationRequired
        ApprovalRequiredForResponse = $ApprovalRequiredForResponse
        ApprovalRequiredForDestructive = $ApprovalRequiredForDestructive
        AllowedOperators = $script:ComplianceGuardState.AllowedOperators
    }
}

function Get-CompliancePolicy {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Mode = $script:ComplianceGuardState.Mode
        TranscriptRequired = $script:ComplianceGuardState.TranscriptRequired
        LoggingRequired = $script:ComplianceGuardState.LoggingRequired
        SignatureValidationRequired = $script:ComplianceGuardState.SignatureValidationRequired
        ApprovalRequiredForResponse = $script:ComplianceGuardState.ApprovalRequiredForResponse
        ApprovalRequiredForDestructive = $script:ComplianceGuardState.ApprovalRequiredForDestructive
        AllowedOperators = $script:ComplianceGuardState.AllowedOperators
        AllowedActionsInAuditMode = $script:ComplianceGuardState.AllowedActionsInAuditMode
        DestructiveActions = $script:ComplianceGuardState.DestructiveActions
    }
}

function Register-TrustedModuleHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$SHA256
    )

    $script:ComplianceGuardState.TrustedHashes[$Path] = $SHA256.ToUpperInvariant()
    return New-ComplianceResult -Action 'RegisterTrustedHash' -Status 'Success' -Message 'Trusted module hash registered' -Details @{ Path = $Path; SHA256 = $SHA256 }
}

function Test-OperatorAuthorization {
    [CmdletBinding()]
    param(
        [string]$Operator = $env:USERNAME
    )

    if (@($script:ComplianceGuardState.AllowedOperators).Count -eq 0) {
        return New-ComplianceResult -Action 'OperatorAuthorization' -Status 'Allowed' -Message 'No operator allowlist configured; access permitted' -Details @{ Operator = $Operator }
    }

    if ($Operator -in $script:ComplianceGuardState.AllowedOperators) {
        return New-ComplianceResult -Action 'OperatorAuthorization' -Status 'Allowed' -Message 'Operator is authorized' -Details @{ Operator = $Operator }
    }

    return New-ComplianceResult -Action 'OperatorAuthorization' -Status 'Denied' -Message 'Operator is not on the allowlist' -Details @{ Operator = $Operator }
}

function Test-TranscriptReady {
    [CmdletBinding()]
    param()

    if (-not $script:ComplianceGuardState.TranscriptRequired) {
        return New-ComplianceResult -Action 'TranscriptCheck' -Status 'Allowed' -Message 'Transcript not required by policy'
    }

    if ($global:TRANSCRIPT) {
        return New-ComplianceResult -Action 'TranscriptCheck' -Status 'Allowed' -Message 'Transcript is active'
    }

    return New-ComplianceResult -Action 'TranscriptCheck' -Status 'Denied' -Message 'Transcript is required but not active'
}

function Test-LoggingReady {
    [CmdletBinding()]
    param()

    if (-not $script:ComplianceGuardState.LoggingRequired) {
        return New-ComplianceResult -Action 'LoggingCheck' -Status 'Allowed' -Message 'Structured logging not required by policy'
    }

    if (Get-Command -Name Write-GhostLog -ErrorAction SilentlyContinue) {
        return New-ComplianceResult -Action 'LoggingCheck' -Status 'Allowed' -Message 'Structured logging function is available'
    }

    return New-ComplianceResult -Action 'LoggingCheck' -Status 'Denied' -Message 'Structured logging function is required but unavailable'
}

function Test-ModuleTrust {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return New-ComplianceResult -Action 'ModuleTrust' -Status 'Denied' -Message 'Module path does not exist' -Details @{ Path = $Path }
    }

    $signature = $null
    $hashStatus = 'NotChecked'
    $hashValue = $null

    try {
        $signature = Get-AuthenticodeSignature -FilePath $Path -ErrorAction Stop
    } catch {}

    try {
        $hashValue = (Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
        if ($script:ComplianceGuardState.TrustedHashes.ContainsKey($Path)) {
            $hashStatus = if ($script:ComplianceGuardState.TrustedHashes[$Path] -eq $hashValue) { 'Match' } else { 'Mismatch' }
        }
    } catch {}

    if ($script:ComplianceGuardState.SignatureValidationRequired) {
        if ($signature -and $signature.Status -eq 'Valid') {
            return New-ComplianceResult -Action 'ModuleTrust' -Status 'Allowed' -Message 'Module signature is valid' -Details @{
                Path = $Path
                SignatureStatus = [string]$signature.Status
                SHA256 = $hashValue
                HashStatus = $hashStatus
            }
        }

        return New-ComplianceResult -Action 'ModuleTrust' -Status 'Denied' -Message 'Valid module signature required by policy' -Details @{
            Path = $Path
            SignatureStatus = if ($signature) { [string]$signature.Status } else { 'Unavailable' }
            SHA256 = $hashValue
            HashStatus = $hashStatus
        }
    }

    return New-ComplianceResult -Action 'ModuleTrust' -Status 'Allowed' -Message 'Module trust check completed' -Details @{
        Path = $Path
        SignatureStatus = if ($signature) { [string]$signature.Status } else { 'Unavailable' }
        SHA256 = $hashValue
        HashStatus = $hashStatus
    }
}

function Test-ActionAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ActionName,
        [string]$Operator = $env:USERNAME
    )

    $operatorCheck = Test-OperatorAuthorization -Operator $Operator
    if ($operatorCheck.Status -eq 'Denied') {
        return New-ComplianceResult -Action 'ActionAllowed' -Status 'Denied' -Message 'Operator authorization failed' -Details @{ ActionName = $ActionName; OperatorCheck = $operatorCheck }
    }

    if ($script:ComplianceGuardState.Mode -eq 'Audit' -and $ActionName -notin $script:ComplianceGuardState.AllowedActionsInAuditMode) {
        return New-ComplianceResult -Action 'ActionAllowed' -Status 'Denied' -Message 'Action not allowed in Audit mode' -Details @{ ActionName = $ActionName; Mode = $script:ComplianceGuardState.Mode }
    }

    $transcriptCheck = Test-TranscriptReady
    if ($transcriptCheck.Status -eq 'Denied') {
        return New-ComplianceResult -Action 'ActionAllowed' -Status 'Denied' -Message 'Transcript requirement not satisfied' -Details @{ ActionName = $ActionName; TranscriptCheck = $transcriptCheck }
    }

    $loggingCheck = Test-LoggingReady
    if ($loggingCheck.Status -eq 'Denied') {
        return New-ComplianceResult -Action 'ActionAllowed' -Status 'Denied' -Message 'Logging requirement not satisfied' -Details @{ ActionName = $ActionName; LoggingCheck = $loggingCheck }
    }

    return New-ComplianceResult -Action 'ActionAllowed' -Status 'Allowed' -Message 'Action allowed by compliance policy' -Details @{ ActionName = $ActionName; Mode = $script:ComplianceGuardState.Mode }
}

function Request-ActionApproval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ActionName,
        [string]$Reason = '',
        [string]$Operator = $env:USERNAME
    )

    $isDestructive = $ActionName -in $script:ComplianceGuardState.DestructiveActions
    $requiresApproval = $false

    if ($script:ComplianceGuardState.Mode -eq 'Response' -and $script:ComplianceGuardState.ApprovalRequiredForResponse) {
        $requiresApproval = $true
    }
    if ($isDestructive -and $script:ComplianceGuardState.ApprovalRequiredForDestructive) {
        $requiresApproval = $true
    }

    if (-not $requiresApproval) {
        return New-ComplianceResult -Action 'RequestApproval' -Status 'Approved' -Message 'Approval not required by policy' -Details @{ ActionName = $ActionName; Operator = $Operator }
    }

    Write-Host ''
    Write-Host '=== COMPLIANCE APPROVAL REQUIRED ===' -ForegroundColor Yellow
    Write-Host "Operator : $Operator" -ForegroundColor Gray
    Write-Host "Action   : $ActionName" -ForegroundColor Gray
    if ($Reason) { Write-Host "Reason   : $Reason" -ForegroundColor Gray }
    Write-Host ''

    $response = Read-Host "Type APPROVE to continue with $ActionName"
    if ($response -eq 'APPROVE') {
        return New-ComplianceResult -Action 'RequestApproval' -Status 'Approved' -Message 'Action approved by operator confirmation' -Details @{ ActionName = $ActionName; Operator = $Operator; Reason = $Reason }
    }

    return New-ComplianceResult -Action 'RequestApproval' -Status 'Denied' -Message 'Action approval denied or not confirmed' -Details @{ ActionName = $ActionName; Operator = $Operator; Reason = $Reason }
}

function Invoke-CompliancePreflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ActionName,
        [string]$Reason = '',
        [string]$Operator = $env:USERNAME,
        [string[]]$ModulePaths = @()
    )

    $actionCheck = Test-ActionAllowed -ActionName $ActionName -Operator $Operator
    if ($actionCheck.Status -eq 'Denied') {
        return [pscustomobject]@{
            Allowed = $false
            ActionCheck = $actionCheck
            Approval = $null
            ModuleTrust = @()
        }
    }

    $moduleChecks = @()
    foreach ($path in $ModulePaths) {
        $check = Test-ModuleTrust -Path $path
        $moduleChecks += $check
        if ($check.Status -eq 'Denied') {
            return [pscustomobject]@{
                Allowed = $false
                ActionCheck = $actionCheck
                Approval = $null
                ModuleTrust = $moduleChecks
            }
        }
    }

    $approval = Request-ActionApproval -ActionName $ActionName -Reason $Reason -Operator $Operator
    if ($approval.Status -ne 'Approved') {
        return [pscustomobject]@{
            Allowed = $false
            ActionCheck = $actionCheck
            Approval = $approval
            ModuleTrust = $moduleChecks
        }
    }

    return [pscustomobject]@{
        Allowed = $true
        ActionCheck = $actionCheck
        Approval = $approval
        ModuleTrust = $moduleChecks
    }
}

Export-ModuleMember -Function @(
    'Set-ComplianceMode',
    'Get-ComplianceMode',
    'Set-CompliancePolicy',
    'Get-CompliancePolicy',
    'Register-TrustedModuleHash',
    'Test-OperatorAuthorization',
    'Test-TranscriptReady',
    'Test-LoggingReady',
    'Test-ModuleTrust',
    'Test-ActionAllowed',
    'Request-ActionApproval',
    'Invoke-CompliancePreflight'
)
