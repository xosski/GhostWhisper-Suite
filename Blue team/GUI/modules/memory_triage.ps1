Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
MemoryTriage.ps1
Blue-team memory triage module with browser safety checks.

Purpose
- Summarize suspicious process-memory characteristics for running processes
- Flag likely in-memory execution indicators defensively
- Surface browser-safety findings in the same module for a single host-risk view

Design notes
- This module is defensive and triage-oriented.
- It does not dump process memory or attempt code execution.
- Browser checks focus on extensions, command-line abuse, policies, and suspicious profiles.
#>

$script:MemoryTriageState = [ordered]@{
    Findings = New-Object System.Collections.Generic.List[object]
    BrowserNames = @('chrome','msedge','firefox','brave','opera')
    SuspiciousChildren = @('powershell.exe','cmd.exe','wscript.exe','cscript.exe','mshta.exe','rundll32.exe','regsvr32.exe')
    SuspiciousBrowserArgsRegex = '(?i)--load-extension|--disable-web-security|--remote-debugging-port|--proxy-server|--user-data-dir|--allow-running-insecure-content|--disable-extensions-except'
    SuspiciousPathRegex = '(?i)\\AppData\\|\\Temp\\|\\ProgramData\\|\\Users\\Public\\|\.tmp$|\.dat$'
}

function Add-MemoryTriageFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Type,
        [Parameter(Mandatory)] [string]$Severity,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Location,
        [Parameter(Mandatory)] [string]$Description,
        [hashtable]$Details = @{}
    )

    $finding = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Type = $Type
        Severity = $Severity.ToUpperInvariant()
        Name = $Name
        Location = $Location
        Description = $Description
        Details = $Details
    }
    $script:MemoryTriageState.Findings.Add($finding) | Out-Null
    return $finding
}

function Get-ProcessInventory {
    [CmdletBinding()]
    param()

    try {
        return @(Get-CimInstance Win32_Process -ErrorAction Stop)
    } catch {
        return @()
    }
}

function Get-UnsignedRunningProcesses {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($proc in Get-ProcessInventory) {
        $path = [string]$proc.ExecutablePath
        if (-not $path -or -not (Test-Path $path)) { continue }
        try {
            $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
            if ($sig.Status -ne 'Valid') {
                $sev = if ($path -match $script:MemoryTriageState.SuspiciousPathRegex) { 'HIGH' } else { 'MEDIUM' }
                $findings += Add-MemoryTriageFinding -Type 'UnsignedProcessImage' -Severity $sev -Name $proc.Name -Location $path -Description 'Running process image is unsigned or invalidly signed' -Details @{
                    PID = $proc.ProcessId
                    CommandLine = $proc.CommandLine
                    SignatureStatus = [string]$sig.Status
                }
            }
        } catch {}
    }
    return $findings
}

function Get-SuspiciousProcessChains {
    [CmdletBinding()]
    param()

    $findings = @()
    $procMap = @{}
    foreach ($proc in Get-ProcessInventory) {
        $procMap[[int]$proc.ProcessId] = $proc
    }

    foreach ($proc in $procMap.Values) {
        $parentId = [int]$proc.ParentProcessId
        if (-not $procMap.ContainsKey($parentId)) { continue }
        $parent = $procMap[$parentId]
        $parentName = ([string]$parent.Name).ToLowerInvariant()
        $childName = ([string]$proc.Name).ToLowerInvariant()

        if ($parentName -in $script:MemoryTriageState.BrowserNames -and $childName -in $script:MemoryTriageState.SuspiciousChildren) {
            $findings += Add-MemoryTriageFinding -Type 'BrowserSpawnedScriptHost' -Severity 'HIGH' -Name $proc.Name -Location ("PID {0} <- PPID {1}" -f $proc.ProcessId, $parentId) -Description 'Browser spawned a suspicious script/interpreter process' -Details @{
                Parent = $parent.Name
                ParentPID = $parent.ProcessId
                Child = $proc.Name
                ChildPID = $proc.ProcessId
                CommandLine = $proc.CommandLine
            }
        }
    }

    return $findings
}

function Get-BrowserCommandLineFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($proc in Get-ProcessInventory) {
        $name = ([string]$proc.Name).ToLowerInvariant()
        if ($name -notin $script:MemoryTriageState.BrowserNames) { continue }
        $cmd = [string]$proc.CommandLine
        if (-not $cmd) { continue }

        if ($cmd -match $script:MemoryTriageState.SuspiciousBrowserArgsRegex) {
            $findings += Add-MemoryTriageFinding -Type 'BrowserCommandLine' -Severity 'HIGH' -Name $proc.Name -Location ("PID {0}" -f $proc.ProcessId) -Description 'Browser launched with suspicious command-line arguments' -Details @{
                PID = $proc.ProcessId
                CommandLine = $cmd
            }
        }
    }
    return $findings
}

function Get-ExecutablePrivateMemoryFindings {
    [CmdletBinding()]
    param()

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class GhostMemNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_BASIC_INFORMATION {
        public IntPtr BaseAddress;
        public IntPtr AllocationBase;
        public uint AllocationProtect;
        public UIntPtr RegionSize;
        public uint State;
        public uint Protect;
        public uint Type;
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(UInt32 access, bool inherit, UInt32 pid);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@ -ErrorAction SilentlyContinue | Out-Null

    $PROCESS_QUERY_INFORMATION = 0x0400
    $PROCESS_VM_READ = 0x0010
    $MEM_COMMIT = 0x1000
    $MEM_PRIVATE = 0x20000
    $PAGE_EXECUTE = 0x10
    $PAGE_EXECUTE_READ = 0x20
    $PAGE_EXECUTE_READWRITE = 0x40
    $PAGE_EXECUTE_WRITECOPY = 0x80

    $findings = @()

    foreach ($proc in (Get-Process -ErrorAction SilentlyContinue)) {
        $handle = [GhostMemNative]::OpenProcess($PROCESS_QUERY_INFORMATION -bor $PROCESS_VM_READ, $false, [uint32]$proc.Id)
        if ($handle -eq [IntPtr]::Zero) { continue }
        try {
            $address = [IntPtr]::Zero
            while ($true) {
                $mbi = New-Object GhostMemNative+MEMORY_BASIC_INFORMATION
                $result = [GhostMemNative]::VirtualQueryEx($handle, $address, [ref]$mbi, [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type]'GhostMemNative+MEMORY_BASIC_INFORMATION'))
                if ($result -le 0) { break }

                $protect = [uint32]$mbi.Protect
                $isExecutable = ($protect -band $PAGE_EXECUTE) -or ($protect -band $PAGE_EXECUTE_READ) -or ($protect -band $PAGE_EXECUTE_READWRITE) -or ($protect -band $PAGE_EXECUTE_WRITECOPY)
                $isPrivateCommitted = ([uint32]$mbi.State -eq $MEM_COMMIT) -and ([uint32]$mbi.Type -eq $MEM_PRIVATE)

                if ($isExecutable -and $isPrivateCommitted) {
                    $sev = if ($protect -band $PAGE_EXECUTE_READWRITE) { 'HIGH' } else { 'MEDIUM' }
                    $findings += Add-MemoryTriageFinding -Type 'ExecutablePrivateMemory' -Severity $sev -Name $proc.ProcessName -Location ("PID {0} @ {1}" -f $proc.Id, $mbi.BaseAddress) -Description 'Committed private executable memory region detected' -Details @{
                        PID = $proc.Id
                        BaseAddress = [string]$mbi.BaseAddress
                        RegionSize = [uint64]$mbi.RegionSize
                        Protect = ('0x{0:X}' -f $protect)
                    }
                }

                $next = [Int64]$mbi.BaseAddress + [Int64][UInt64]$mbi.RegionSize
                if ($next -le 0) { break }
                $address = [IntPtr]$next
            }
        } finally {
            [GhostMemNative]::CloseHandle($handle) | Out-Null
        }
    }

    return $findings
}

function Get-ModulePathAnomalies {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        try {
            foreach ($module in $proc.Modules) {
                $path = [string]$module.FileName
                if ($path -match $script:MemoryTriageState.SuspiciousPathRegex) {
                    $findings += Add-MemoryTriageFinding -Type 'SuspiciousModulePath' -Severity 'MEDIUM' -Name $proc.ProcessName -Location $path -Description 'Loaded module from suspicious path' -Details @{
                        PID = $proc.Id
                        Module = $module.ModuleName
                    }
                }
            }
        } catch {}
    }
    return $findings
}

function Get-BrowserExtensionInventory {
    [CmdletBinding()]
    param()

    $findings = @()
    $profiles = @(
        @{ Browser = 'Chrome'; Root = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data' },
        @{ Browser = 'Edge';   Root = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data' },
        @{ Browser = 'Brave';  Root = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data' }
    )

    foreach ($profile in $profiles) {
        if (-not (Test-Path $profile.Root)) { continue }
        try {
            Get-ChildItem -Path $profile.Root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $extensionsRoot = Join-Path $_.FullName 'Extensions'
                if (-not (Test-Path $extensionsRoot)) { return }
                Get-ChildItem -Path $extensionsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $extDir = $_
                    $sev = if ($extDir.FullName -match $script:MemoryTriageState.SuspiciousPathRegex) { 'HIGH' } else { 'LOW' }
                    $findings += Add-MemoryTriageFinding -Type 'BrowserExtension' -Severity $sev -Name $extDir.Name -Location $extDir.FullName -Description 'Browser extension installed' -Details @{
                        Browser = $profile.Browser
                        Profile = (Split-Path $_.Parent.FullName -Leaf)
                    }
                }
            }
        } catch {}
    }

    return $findings
}

function Get-BrowserPolicyFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    $policyKeys = @(
        'HKLM:\SOFTWARE\Policies\Google\Chrome',
        'HKLM:\SOFTWARE\Policies\Microsoft\Edge',
        'HKCU:\SOFTWARE\Policies\Google\Chrome',
        'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
    )

    foreach ($key in $policyKeys) {
        try {
            if (-not (Test-Path $key)) { continue }
            $item = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($prop in $item.PSObject.Properties) {
                if ($prop.Name -match '^PS') { continue }
                $value = [string]$prop.Value
                $sev = if ($prop.Name -match 'ExtensionInstallForceList|Proxy|DeveloperToolsAvailability|AutoLaunchProtocolsFromOrigins') { 'HIGH' } else { 'MEDIUM' }
                $findings += Add-MemoryTriageFinding -Type 'BrowserPolicy' -Severity $sev -Name $prop.Name -Location $key -Description 'Browser policy present' -Details @{
                    Value = $value
                }
            }
        } catch {}
    }

    return $findings
}

function Get-BrowserProfilePathFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    $roots = @(
        Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data',
        Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data',
        Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    )

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        if ($root -match $script:MemoryTriageState.SuspiciousPathRegex) {
            $findings += Add-MemoryTriageFinding -Type 'BrowserProfilePath' -Severity 'MEDIUM' -Name (Split-Path $root -Leaf) -Location $root -Description 'Browser profile path in suspicious location' -Details @{}
        }
    }

    return $findings
}

function Get-BrowserSafetySummary {
    [CmdletBinding()]
    param()

    $browserFindings = @()
    $browserFindings += Get-BrowserCommandLineFindings
    $browserFindings += Get-BrowserExtensionInventory
    $browserFindings += Get-BrowserPolicyFindings
    $browserFindings += Get-BrowserProfilePathFindings
    $browserFindings += Get-SuspiciousProcessChains

    return $browserFindings
}

function Start-MemoryTriage {
    [CmdletBinding()]
    param(
        [switch]$IncludeBrowserChecks = $true
    )

    $script:MemoryTriageState.Findings.Clear()

    $null = Get-UnsignedRunningProcesses
    $null = Get-ExecutablePrivateMemoryFindings
    $null = Get-ModulePathAnomalies
    $null = Get-SuspiciousProcessChains

    if ($IncludeBrowserChecks) {
        $null = Get-BrowserCommandLineFindings
        $null = Get-BrowserExtensionInventory
        $null = Get-BrowserPolicyFindings
        $null = Get-BrowserProfilePathFindings
    }

    return Get-MemoryTriageSummary -Findings @($script:MemoryTriageState.Findings)
}

function Get-MemoryTriageSummary {
    [CmdletBinding()]
    param(
        [array]$Findings = @($script:MemoryTriageState.Findings)
    )

    $bySeverity = @{}
    $byType = @{}
    foreach ($f in $Findings) {
        if (-not $bySeverity.ContainsKey($f.Severity)) { $bySeverity[$f.Severity] = 0 }
        if (-not $byType.ContainsKey($f.Type)) { $byType[$f.Type] = 0 }
        $bySeverity[$f.Severity]++
        $byType[$f.Type]++
    }

    [pscustomobject]@{
        Total = $Findings.Count
        HighSeverity = @($Findings | Where-Object Severity -eq 'HIGH').Count
        BySeverity = $bySeverity
        ByType = $byType
        Findings = $Findings
    }
}

function Get-BrowserArtifactSummary {
    [CmdletBinding()]
    param()

    $findings = Get-BrowserSafetySummary
    $byType = @{}
    foreach ($f in $findings) {
        if (-not $byType.ContainsKey($f.Type)) { $byType[$f.Type] = 0 }
        $byType[$f.Type]++
    }

    [pscustomobject]@{
        Total = $findings.Count
        HighSeverity = @($findings | Where-Object Severity -eq 'HIGH').Count
        ByType = $byType
        Findings = $findings
    }
}

Export-ModuleMember -Function @(
    'Get-UnsignedRunningProcesses',
    'Get-SuspiciousProcessChains',
    'Get-BrowserCommandLineFindings',
    'Get-ExecutablePrivateMemoryFindings',
    'Get-ModulePathAnomalies',
    'Get-BrowserExtensionInventory',
    'Get-BrowserPolicyFindings',
    'Get-BrowserProfilePathFindings',
    'Get-BrowserSafetySummary',
    'Start-MemoryTriage',
    'Get-MemoryTriageSummary',
    'Get-BrowserArtifactSummary'
)
