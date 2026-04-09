Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Containment.ps1
Blue-team containment module.

Purpose
- Provide safe, auditable host containment actions for incident response
- Support host isolation, targeted process stopping, service/task disabling,
  and indicator blocking using Windows firewall rules
- Return structured results suitable for GhostShield logging and reporting

Safety notes
- Defensive only
- Uses confirmation-friendly, reversible actions where possible
- Supports -WhatIf for simulation
#>

$script:ContainmentState = [ordered]@{
    RulePrefix = 'GhostShield-Containment'
    AllowedManagementIPs = @()
    AllowedManagementSubnets = @()
    Findings = New-Object System.Collections.Generic.List[object]
}

function New-ContainmentResult {
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

function Set-ContainmentAllowList {
    [CmdletBinding()]
    param(
        [string[]]$ManagementIPs = @(),
        [string[]]$ManagementSubnets = @()
    )

    $script:ContainmentState.AllowedManagementIPs = @($ManagementIPs | Where-Object { $_ } | Sort-Object -Unique)
    $script:ContainmentState.AllowedManagementSubnets = @($ManagementSubnets | Where-Object { $_ } | Sort-Object -Unique)

    return New-ContainmentResult -Action 'SetAllowList' -Status 'Success' -Target 'ContainmentConfig' -Message 'Containment allow list updated' -Details @{
        ManagementIPs = $script:ContainmentState.AllowedManagementIPs
        ManagementSubnets = $script:ContainmentState.AllowedManagementSubnets
    }
}

function Get-ContainmentAllowList {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        ManagementIPs = $script:ContainmentState.AllowedManagementIPs
        ManagementSubnets = $script:ContainmentState.AllowedManagementSubnets
    }
}

function Get-ContainmentRules {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue) {
            return @(Get-NetFirewallRule -DisplayName "$($script:ContainmentState.RulePrefix)*" -ErrorAction SilentlyContinue |
                Select-Object DisplayName, Enabled, Direction, Action, Profile)
        }
    } catch {}
    return @()
}

function Remove-ContainmentRules {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $results = @()
    try {
        $rules = Get-NetFirewallRule -DisplayName "$($script:ContainmentState.RulePrefix)*" -ErrorAction SilentlyContinue
        foreach ($rule in $rules) {
            if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Remove containment firewall rule')) {
                Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
                $results += New-ContainmentResult -Action 'RemoveFirewallRule' -Status 'Success' -Target $rule.DisplayName -Message 'Containment firewall rule removed'
            }
        }
    } catch {
        $results += New-ContainmentResult -Action 'RemoveFirewallRule' -Status 'Error' -Target 'Firewall' -Message 'Failed to remove containment rules' -Details @{ Error = $_.Exception.Message }
    }

    return $results
}

function Start-HostIsolation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$AllowIPs = @(),
        [string[]]$AllowSubnets = @(),
        [switch]$PreserveRDP
    )

    $results = @()
    $allowList = @($script:ContainmentState.AllowedManagementIPs + $AllowIPs | Sort-Object -Unique)
    $allowSubnets = @($script:ContainmentState.AllowedManagementSubnets + $AllowSubnets | Sort-Object -Unique)

    try {
        if (-not (Get-Command New-NetFirewallRule -ErrorAction SilentlyContinue)) {
            return @(New-ContainmentResult -Action 'HostIsolation' -Status 'Error' -Target $env:COMPUTERNAME -Message 'Firewall cmdlets are unavailable')
        }

        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Apply firewall-based host isolation')) {
            $null = Remove-ContainmentRules -WhatIf:$WhatIfPreference

            $baseName = "$($script:ContainmentState.RulePrefix)-BlockOutbound"
            New-NetFirewallRule -DisplayName $baseName -Direction Outbound -Action Block -Enabled True -Profile Any -ErrorAction Stop | Out-Null
            $results += New-ContainmentResult -Action 'HostIsolation' -Status 'Success' -Target $baseName -Message 'Outbound traffic blocked'

            $inboundName = "$($script:ContainmentState.RulePrefix)-BlockInbound"
            New-NetFirewallRule -DisplayName $inboundName -Direction Inbound -Action Block -Enabled True -Profile Any -ErrorAction Stop | Out-Null
            $results += New-ContainmentResult -Action 'HostIsolation' -Status 'Success' -Target $inboundName -Message 'Inbound traffic blocked'

            foreach ($ip in $allowList) {
                $ruleName = "$($script:ContainmentState.RulePrefix)-AllowIP-$($ip -replace '[^0-9A-Za-z_-]','_')"
                New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Enabled True -RemoteAddress $ip -Profile Any -ErrorAction SilentlyContinue | Out-Null
                New-NetFirewallRule -DisplayName "$ruleName-Out" -Direction Outbound -Action Allow -Enabled True -RemoteAddress $ip -Profile Any -ErrorAction SilentlyContinue | Out-Null
                $results += New-ContainmentResult -Action 'AllowManagementIP' -Status 'Success' -Target $ip -Message 'Management IP allowed during isolation'
            }

            foreach ($subnet in $allowSubnets) {
                $ruleName = "$($script:ContainmentState.RulePrefix)-AllowSubnet-$($subnet -replace '[^0-9A-Za-z_-]','_')"
                New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Enabled True -RemoteAddress $subnet -Profile Any -ErrorAction SilentlyContinue | Out-Null
                New-NetFirewallRule -DisplayName "$ruleName-Out" -Direction Outbound -Action Allow -Enabled True -RemoteAddress $subnet -Profile Any -ErrorAction SilentlyContinue | Out-Null
                $results += New-ContainmentResult -Action 'AllowManagementSubnet' -Status 'Success' -Target $subnet -Message 'Management subnet allowed during isolation'
            }

            if ($PreserveRDP) {
                $rdpName = "$($script:ContainmentState.RulePrefix)-AllowRDP"
                New-NetFirewallRule -DisplayName $rdpName -Direction Inbound -Action Allow -Enabled True -Protocol TCP -LocalPort 3389 -Profile Any -ErrorAction SilentlyContinue | Out-Null
                $results += New-ContainmentResult -Action 'AllowRDP' -Status 'Success' -Target 'TCP/3389' -Message 'RDP preserved during isolation'
            }
        }
    } catch {
        $results += New-ContainmentResult -Action 'HostIsolation' -Status 'Error' -Target $env:COMPUTERNAME -Message 'Failed to apply host isolation' -Details @{ Error = $_.Exception.Message }
    }

    return $results
}

function Stop-SuspiciousProcess {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$PID,
        [string]$Name
    )

    try {
        $proc = $null
        if ($PID) {
            $proc = Get-Process -Id $PID -ErrorAction Stop
        } elseif ($Name) {
            $proc = Get-Process -Name $Name -ErrorAction Stop | Select-Object -First 1
        } else {
            return New-ContainmentResult -Action 'StopProcess' -Status 'Error' -Target 'Process' -Message 'PID or Name is required'
        }

        if ($PSCmdlet.ShouldProcess("$($proc.ProcessName) [$($proc.Id)]", 'Stop process')) {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            return New-ContainmentResult -Action 'StopProcess' -Status 'Success' -Target "$($proc.ProcessName) [$($proc.Id)]" -Message 'Process terminated'
        }
    } catch {
        return New-ContainmentResult -Action 'StopProcess' -Status 'Error' -Target ($PID ? $PID : $Name) -Message 'Failed to stop process' -Details @{ Error = $_.Exception.Message }
    }
}

function Suspend-SuspiciousProcess {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$PID
    )

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class GhostSuspendNative {
    [DllImport("ntdll.dll", SetLastError=true)]
    public static extern int NtSuspendProcess(IntPtr processHandle);
}
"@ -ErrorAction SilentlyContinue | Out-Null

    try {
        $proc = Get-Process -Id $PID -ErrorAction Stop
        if ($PSCmdlet.ShouldProcess("$($proc.ProcessName) [$PID]", 'Suspend process')) {
            $result = [GhostSuspendNative]::NtSuspendProcess($proc.Handle)
            if ($result -eq 0) {
                return New-ContainmentResult -Action 'SuspendProcess' -Status 'Success' -Target "$($proc.ProcessName) [$PID]" -Message 'Process suspended'
            }
            return New-ContainmentResult -Action 'SuspendProcess' -Status 'Error' -Target "$($proc.ProcessName) [$PID]" -Message 'NtSuspendProcess returned a non-zero status' -Details @{ NtStatus = $result }
        }
    } catch {
        return New-ContainmentResult -Action 'SuspendProcess' -Status 'Error' -Target $PID -Message 'Failed to suspend process' -Details @{ Error = $_.Exception.Message }
    }
}

function Disable-SuspiciousTask {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$TaskName,
        [string]$TaskPath = '\'
    )

    try {
        if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Disable scheduled task')) {
            Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-Null
            return New-ContainmentResult -Action 'DisableTask' -Status 'Success' -Target "$TaskPath$TaskName" -Message 'Scheduled task disabled'
        }
    } catch {
        return New-ContainmentResult -Action 'DisableTask' -Status 'Error' -Target "$TaskPath$TaskName" -Message 'Failed to disable scheduled task' -Details @{ Error = $_.Exception.Message }
    }
}

function Disable-SuspiciousService {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$ServiceName,
        [switch]$StopIfRunning
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($PSCmdlet.ShouldProcess($ServiceName, 'Disable service')) {
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
            if ($StopIfRunning -and $service.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            }
            return New-ContainmentResult -Action 'DisableService' -Status 'Success' -Target $ServiceName -Message 'Service disabled' -Details @{ StopIfRunning = [bool]$StopIfRunning }
        }
    } catch {
        return New-ContainmentResult -Action 'DisableService' -Status 'Error' -Target $ServiceName -Message 'Failed to disable service' -Details @{ Error = $_.Exception.Message }
    }
}

function Block-Indicator {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$Indicator,
        [ValidateSet('IP','Domain','Port')] [string]$Type = 'IP'
    )

    try {
        switch ($Type) {
            'IP' {
                $ruleName = "$($script:ContainmentState.RulePrefix)-BlockIP-$($Indicator -replace '[^0-9A-Za-z_-]','_')"
                if ($PSCmdlet.ShouldProcess($Indicator, 'Block remote IP')) {
                    New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -RemoteAddress $Indicator -Profile Any -ErrorAction Stop | Out-Null
                    New-NetFirewallRule -DisplayName "$ruleName-In" -Direction Inbound -Action Block -RemoteAddress $Indicator -Profile Any -ErrorAction SilentlyContinue | Out-Null
                    return New-ContainmentResult -Action 'BlockIndicator' -Status 'Success' -Target $Indicator -Message 'IP blocked by firewall' -Details @{ Type = $Type; RuleName = $ruleName }
                }
            }
            'Port' {
                $ruleName = "$($script:ContainmentState.RulePrefix)-BlockPort-$Indicator"
                if ($PSCmdlet.ShouldProcess($Indicator, 'Block TCP port')) {
                    New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -Protocol TCP -RemotePort $Indicator -Profile Any -ErrorAction Stop | Out-Null
                    return New-ContainmentResult -Action 'BlockIndicator' -Status 'Success' -Target $Indicator -Message 'Port blocked by firewall' -Details @{ Type = $Type; RuleName = $ruleName }
                }
            }
            'Domain' {
                return New-ContainmentResult -Action 'BlockIndicator' -Status 'Skipped' -Target $Indicator -Message 'Domain blocking is not implemented directly in firewall rules; use DNS sinkhole or proxy controls' -Details @{ Type = $Type }
            }
        }
    } catch {
        return New-ContainmentResult -Action 'BlockIndicator' -Status 'Error' -Target $Indicator -Message 'Failed to block indicator' -Details @{ Type = $Type; Error = $_.Exception.Message }
    }
}

function Disconnect-SmbSessions {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $results = @()
    try {
        if (-not (Get-Command Get-SmbSession -ErrorAction SilentlyContinue)) {
            return @(New-ContainmentResult -Action 'DisconnectSMB' -Status 'Skipped' -Target 'SMB' -Message 'SMB cmdlets are unavailable')
        }

        foreach ($session in (Get-SmbSession -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($session.ClientComputerName, 'Close SMB session')) {
                Close-SmbSession -SessionId $session.SessionId -Force -ErrorAction SilentlyContinue | Out-Null
                $results += New-ContainmentResult -Action 'DisconnectSMB' -Status 'Success' -Target $session.ClientComputerName -Message 'SMB session closed' -Details @{ SessionId = $session.SessionId }
            }
        }
    } catch {
        $results += New-ContainmentResult -Action 'DisconnectSMB' -Status 'Error' -Target 'SMB' -Message 'Failed to close SMB sessions' -Details @{ Error = $_.Exception.Message }
    }

    return $results
}

function Get-ContainmentStatus {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        AllowList = Get-ContainmentAllowList
        FirewallRules = Get-ContainmentRules
    }
}

Export-ModuleMember -Function @(
    'Set-ContainmentAllowList',
    'Get-ContainmentAllowList',
    'Get-ContainmentRules',
    'Remove-ContainmentRules',
    'Start-HostIsolation',
    'Stop-SuspiciousProcess',
    'Suspend-SuspiciousProcess',
    'Disable-SuspiciousTask',
    'Disable-SuspiciousService',
    'Block-Indicator',
    'Disconnect-SmbSessions',
    'Get-ContainmentStatus'
)
