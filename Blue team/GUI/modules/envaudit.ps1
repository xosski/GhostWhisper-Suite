Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
EnvAudit.ps1
Blue-team environment and baseline audit module.

Purpose
- Collect host environment and security-baseline information
- Provide quick admin/context checks for GhostShieldBootstrap
- Surface posture details such as Secure Boot, BitLocker, Defender, local admins, startup state
- Return structured objects suitable for logging, reporting, and artifact collection

Design notes
- Defensive and read-only
- Best-effort: individual checks degrade gracefully if cmdlets/features are unavailable
#>

$script:EnvAuditState = [ordered]@{
    Baseline = $null
}

function New-EnvAuditResult {
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

function Test-AdminContext {
    [CmdletBinding()]
    param()

    try {
        $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        return [pscustomobject]@{
            User = "$env:USERDOMAIN\$env:USERNAME"
            IsAdmin = $isAdmin
            Integrity = if ($isAdmin) { 'Elevated' } else { 'Standard' }
        }
    } catch {
        return [pscustomobject]@{
            User = "$env:USERDOMAIN\$env:USERNAME"
            IsAdmin = $false
            Integrity = 'Unknown'
            Error = $_.Exception.Message
        }
    }
}

function Get-OSBaseline {
    [CmdletBinding()]
    param()

    $result = [ordered]@{}

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $result.Caption = $os.Caption
        $result.Version = $os.Version
        $result.BuildNumber = $os.BuildNumber
        $result.InstallDate = $os.InstallDate
        $result.LastBootUpTime = $os.LastBootUpTime
        $result.CSName = $os.CSName
        $result.Architecture = $os.OSArchitecture
    } catch {
        $result.Error = $_.Exception.Message
    }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $result.Manufacturer = $cs.Manufacturer
        $result.Model = $cs.Model
        $result.Domain = $cs.Domain
        $result.PartOfDomain = $cs.PartOfDomain
        $result.TotalPhysicalMemory = $cs.TotalPhysicalMemory
    } catch {}

    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $result.BIOSVersion = ($bios.SMBIOSBIOSVersion -join '; ')
        $result.BIOSSerial = $bios.SerialNumber
    } catch {}

    return [pscustomobject]$result
}

function Get-PowerShellBaseline {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        Version = $PSVersionTable.PSVersion.ToString()
        Edition = $PSVersionTable.PSEdition
        CLRVersion = $PSVersionTable.CLRVersion
        WSManStackVersion = $PSVersionTable.WSManStackVersion
        ProcessArchitecture = $env:PROCESSOR_ARCHITECTURE
    }
}

function Get-SecureBootBaseline {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
            $enabled = Confirm-SecureBootUEFI -ErrorAction Stop
            return [pscustomobject]@{
                Available = $true
                Enabled = [bool]$enabled
            }
        }
    } catch {
        return [pscustomobject]@{
            Available = $true
            Enabled = $false
            Error = $_.Exception.Message
        }
    }

    [pscustomobject]@{
        Available = $false
        Enabled = $null
        Error = 'Confirm-SecureBootUEFI unavailable'
    }
}

function Get-BitLockerBaseline {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            return @(Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionMethod, AutoUnlockEnabled)
        }
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    return @([pscustomobject]@{ Error = 'Get-BitLockerVolume unavailable' })
}

function Get-DefenderBaseline {
    [CmdletBinding()]
    param()

    $result = [ordered]@{}

    try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $result.AMServiceEnabled = $mp.AMServiceEnabled
            $result.AntispywareEnabled = $mp.AntispywareEnabled
            $result.AntivirusEnabled = $mp.AntivirusEnabled
            $result.RealTimeProtectionEnabled = $mp.RealTimeProtectionEnabled
            $result.IoavProtectionEnabled = $mp.IoavProtectionEnabled
            $result.BehaviorMonitorEnabled = $mp.BehaviorMonitorEnabled
            $result.TamperProtectionSource = $mp.TamperProtectionSource
            $result.AntivirusSignatureVersion = $mp.AntivirusSignatureVersion
            $result.QuickScanAge = $mp.QuickScanAge
            $result.FullScanAge = $mp.FullScanAge
        } else {
            $result.Error = 'Get-MpComputerStatus unavailable'
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Get-FirewallBaseline {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
            return @(Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, AllowLocalFirewallRules, NotifyOnListen)
        }
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    return @([pscustomobject]@{ Error = 'Get-NetFirewallProfile unavailable' })
}

function Get-LocalAdminBaseline {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
            return @(Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | Select-Object Name, ObjectClass, PrincipalSource)
        }
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    try {
        $lines = & net localgroup Administrators 2>$null
        $members = @($lines | Where-Object { $_ -and $_ -notmatch 'command completed successfully|Alias name|Comment|Members|---' } | ForEach-Object {
            [pscustomobject]@{ Name = $_.Trim(); ObjectClass = 'Unknown'; PrincipalSource = 'Unknown' }
        })
        return $members
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-LocalUserBaseline {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
            return @(Get-LocalUser -ErrorAction Stop | Select-Object Name, Enabled, LastLogon, PasswordRequired, PasswordExpires, UserMayChangePassword)
        }
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    return @()
}

function Get-SignedInUsersBaseline {
    [CmdletBinding()]
    param()

    $users = @()

    try {
        $quser = & quser 2>$null
        if ($quser) {
            foreach ($line in ($quser | Select-Object -Skip 1)) {
                $clean = ($line -replace '^\s+','') -replace '\s{2,}', '|'
                $parts = $clean.Split('|')
                if ($parts.Count -ge 4) {
                    $users += [pscustomobject]@{
                        UserName = $parts[0].TrimStart('>')
                        SessionName = $parts[1]
                        Id = $parts[2]
                        State = $parts[3]
                    }
                }
            }
        }
    } catch {}

    try {
        Get-CimInstance Win32_LoggedOnUser -ErrorAction Stop | ForEach-Object {
            if ($_.Antecedent -match 'Domain="(?<Domain>[^"]+)",Name="(?<Name>[^"]+)"') {
                $users += [pscustomobject]@{
                    UserName = "$($Matches.Domain)\$($Matches.Name)"
                    SessionName = $null
                    Id = $null
                    State = 'LoggedOn'
                }
            }
        }
    } catch {}

    return @($users | Sort-Object UserName -Unique)
}

function Get-StartupSurfaceBaseline {
    [CmdletBinding()]
    param()

    $result = [ordered]@{
        RunKeys = @()
        StartupFolders = @()
        ScheduledTasks = @()
        Services = @()
    }

    $runPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    )

    foreach ($path in $runPaths) {
        try {
            if (-not (Test-Path $path)) { continue }
            $props = Get-ItemProperty -Path $path
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -notmatch '^PS') {
                    $result.RunKeys += [pscustomobject]@{ Path = $path; Name = $p.Name; Value = [string]$p.Value }
                }
            }
        } catch {}
    }

    foreach ($folder in @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )) {
        try {
            if (-not (Test-Path $folder)) { continue }
            $result.StartupFolders += @(Get-ChildItem -Path $folder -Force -ErrorAction Stop | Select-Object Name, FullName, LastWriteTime, Length)
        } catch {}
    }

    try {
        $result.ScheduledTasks = @(Get-ScheduledTask -ErrorAction Stop | Select-Object TaskName, TaskPath, State, Author, URI)
    } catch {}

    try {
        $result.Services = @(Get-CimInstance Win32_Service -ErrorAction Stop | Select-Object Name, DisplayName, StartMode, State, StartName, PathName)
    } catch {}

    return [pscustomobject]$result
}

function Get-NetworkBaseline {
    [CmdletBinding()]
    param()

    $result = [ordered]@{
        Adapters = @()
        IPs = @()
        DNS = @()
        Routes = @()
    }

    try {
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $result.Adapters = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, Status, LinkSpeed, MacAddress, InterfaceDescription)
        }
    } catch {}

    try {
        if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
            $result.IPs = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -notmatch '^169\.' } | Select-Object InterfaceAlias, IPAddress, PrefixLength)
        }
    } catch {}

    try {
        if (Get-Command Get-DnsClientServerAddress -ErrorAction SilentlyContinue) {
            $result.DNS = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Select-Object InterfaceAlias, ServerAddresses)
        }
    } catch {}

    try {
        if (Get-Command Get-NetRoute -ErrorAction SilentlyContinue) {
            $result.Routes = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop | Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric)
        }
    } catch {}

    return [pscustomobject]$result
}

function Get-BrowserBaseline {
    [CmdletBinding()]
    param()

    $result = [ordered]@{
        ChromeProfiles = @()
        EdgeProfiles = @()
        FirefoxProfiles = @()
    }

    try {
        $chromeRoot = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
        if (Test-Path $chromeRoot) {
            $result.ChromeProfiles = @(Get-ChildItem -Path $chromeRoot -Directory -ErrorAction SilentlyContinue | Select-Object Name, FullName, LastWriteTime)
        }
    } catch {}

    try {
        $edgeRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
        if (Test-Path $edgeRoot) {
            $result.EdgeProfiles = @(Get-ChildItem -Path $edgeRoot -Directory -ErrorAction SilentlyContinue | Select-Object Name, FullName, LastWriteTime)
        }
    } catch {}

    try {
        $ffRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
        if (Test-Path $ffRoot) {
            $result.FirefoxProfiles = @(Get-ChildItem -Path $ffRoot -Directory -ErrorAction SilentlyContinue | Select-Object Name, FullName, LastWriteTime)
        }
    } catch {}

    return [pscustomobject]$result
}

function Get-EnvironmentAssessment {
    [CmdletBinding()]
    param()

    $assessment = [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        Hostname = $env:COMPUTERNAME
        Operator = "$env:USERDOMAIN\$env:USERNAME"
        AdminContext = Test-AdminContext
        OS = Get-OSBaseline
        PowerShell = Get-PowerShellBaseline
        SecureBoot = Get-SecureBootBaseline
        BitLocker = Get-BitLockerBaseline
        Defender = Get-DefenderBaseline
        Firewall = Get-FirewallBaseline
        LocalAdmins = Get-LocalAdminBaseline
        LocalUsers = Get-LocalUserBaseline
        SignedInUsers = Get-SignedInUsersBaseline
        StartupSurfaces = Get-StartupSurfaceBaseline
        Network = Get-NetworkBaseline
        Browsers = Get-BrowserBaseline
    }

    $script:EnvAuditState.Baseline = $assessment
    return $assessment
}

function Get-SecurityBaseline {
    [CmdletBinding()]
    param()

    $envData = Get-EnvironmentAssessment

    $issues = New-Object System.Collections.Generic.List[object]

    if (-not $envData.AdminContext.IsAdmin) {
        $issues.Add([pscustomobject]@{ Severity = 'INFO'; Area = 'ExecutionContext'; Message = 'Console is not elevated; some checks/actions may be limited.' }) | Out-Null
    }

    if ($envData.SecureBoot.Available -and -not $envData.SecureBoot.Enabled) {
        $issues.Add([pscustomobject]@{ Severity = 'MEDIUM'; Area = 'SecureBoot'; Message = 'Secure Boot is disabled.' }) | Out-Null
    }

    if ($envData.Defender.PSObject.Properties.Name -contains 'RealTimeProtectionEnabled') {
        if (-not $envData.Defender.RealTimeProtectionEnabled) {
            $issues.Add([pscustomobject]@{ Severity = 'HIGH'; Area = 'Defender'; Message = 'Real-time protection is disabled.' }) | Out-Null
        }
    }

    foreach ($profile in @($envData.Firewall)) {
        if ($profile.Enabled -eq $false) {
            $issues.Add([pscustomobject]@{ Severity = 'HIGH'; Area = 'Firewall'; Message = "Firewall profile disabled: $($profile.Name)" }) | Out-Null
        }
    }

    if (@($envData.LocalAdmins).Count -gt 5) {
        $issues.Add([pscustomobject]@{ Severity = 'MEDIUM'; Area = 'LocalAdmins'; Message = "High number of local administrators: $(@($envData.LocalAdmins).Count)" }) | Out-Null
    }

    [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        Hostname = $envData.Hostname
        Issues = @($issues)
        IssueCount = @($issues).Count
        HighSeverity = @(@($issues) | Where-Object Severity -eq 'HIGH').Count
        MediumSeverity = @(@($issues) | Where-Object Severity -eq 'MEDIUM').Count
        InfoSeverity = @(@($issues) | Where-Object Severity -eq 'INFO').Count
    }
}

Export-ModuleMember -Function @(
    'Test-AdminContext',
    'Get-OSBaseline',
    'Get-PowerShellBaseline',
    'Get-SecureBootBaseline',
    'Get-BitLockerBaseline',
    'Get-DefenderBaseline',
    'Get-FirewallBaseline',
    'Get-LocalAdminBaseline',
    'Get-LocalUserBaseline',
    'Get-SignedInUsersBaseline',
    'Get-StartupSurfaceBaseline',
    'Get-NetworkBaseline',
    'Get-BrowserBaseline',
    'Get-EnvironmentAssessment',
    'Get-SecurityBaseline'
)
