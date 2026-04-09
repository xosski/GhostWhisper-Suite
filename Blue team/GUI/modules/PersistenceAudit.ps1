Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
PersistenceAudit.ps1
Blue-team persistence + suspicious runtime audit module.

Purpose
- Enumerate common persistence mechanisms
- Inspect currently running processes for suspicious runtime indicators
- Flag likely in-memory execution patterns (private executable memory, RWX, odd parent-child chains)
- Provide structured findings back to GhostShieldBootstrap

Scope / limitations
- This is defensive triage. It does not dump or modify memory.
- It can identify suspicious executable memory characteristics, but it does not prove shellcode by itself.
- "Unallocated hard drive space execution" is not treated as a normal execution source; instead we audit
  deleted-file-backed persistence clues, suspicious image paths, ADS usage, temp paths, and odd launch origins.
#>

$script:PersistenceAuditState = [ordered]@{
    Findings = New-Object System.Collections.Generic.List[object]
    SuspiciousParents = @('winword.exe','excel.exe','outlook.exe','acrord32.exe','chrome.exe','msedge.exe','iexplore.exe')
    SuspiciousChildren = @('powershell.exe','cmd.exe','wscript.exe','cscript.exe','rundll32.exe','regsvr32.exe','mshta.exe')
    SuspiciousPathRegex = '(?i)\\AppData\\|\\Temp\\|\\ProgramData\\|\\Users\\Public\\|\\Recycle\\|:Zone\\.|\.tmp$|\.dat$|\\Tasks\\'
}

function Add-PersistenceFinding {
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
    $script:PersistenceAuditState.Findings.Add($finding) | Out-Null
    return $finding
}

function Get-RunKeyAudit {
    [CmdletBinding()]
    param()

    $findings = @()
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($path in $paths) {
        try {
            if (-not (Test-Path $path)) { continue }
            $props = Get-ItemProperty -Path $path
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -match '^PS') { continue }
                $value = [string]$p.Value
                $sev = if ($value -match $script:PersistenceAuditState.SuspiciousPathRegex) { 'HIGH' } else { 'MEDIUM' }
                $findings += Add-PersistenceFinding -Type 'Autorun' -Severity $sev -Name $p.Name -Location $path -Description 'Autorun registry entry present' -Details @{
                    Value = $value
                    SuspiciousPath = [bool]($value -match $script:PersistenceAuditState.SuspiciousPathRegex)
                }
            }
        } catch {}
    }

    return $findings
}

function Get-StartupFolderAudit {
    [CmdletBinding()]
    param()

    $findings = @()
    $folders = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    foreach ($folder in $folders) {
        try {
            if (-not (Test-Path $folder)) { continue }
            Get-ChildItem -Path $folder -Force -ErrorAction Stop | ForEach-Object {
                $sev = if ($_.FullName -match $script:PersistenceAuditState.SuspiciousPathRegex) { 'HIGH' } else { 'MEDIUM' }
                $findings += Add-PersistenceFinding -Type 'StartupFolder' -Severity $sev -Name $_.Name -Location $_.FullName -Description 'Startup folder item present' -Details @{
                    Length = $_.Length
                    LastWriteTime = $_.LastWriteTime
                }
            }
        } catch {}
    }

    return $findings
}

function Get-ScheduledTaskAudit {
    [CmdletBinding()]
    param()

    $findings = @()
    try {
        Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
            $task = $_
            $actions = @()
            try { $actions = @($task.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) } catch {}
            $actionText = ($actions -join ' | ')
            $sev = if ($actionText -match $script:PersistenceAuditState.SuspiciousPathRegex -or $actionText -match 'powershell|mshta|rundll32|regsvr32|wscript|cscript') { 'HIGH' } else { 'MEDIUM' }
            $findings += Add-PersistenceFinding -Type 'ScheduledTask' -Severity $sev -Name $task.TaskName -Location ($task.TaskPath + $task.TaskName) -Description 'Scheduled task present' -Details @{
                State = [string]$task.State
                Author = $task.Author
                Actions = $actions
            }
        }
    } catch {}
    return $findings
}

function Get-ServicePersistenceAudit {
    [CmdletBinding()]
    param()

    $findings = @()
    try {
        Get-CimInstance Win32_Service -ErrorAction Stop | ForEach-Object {
            $svc = $_
            $pathName = [string]$svc.PathName
            if (-not $pathName) { return }
            $sev = if ($pathName -match $script:PersistenceAuditState.SuspiciousPathRegex -or $pathName -match 'powershell|cmd\.exe|rundll32|regsvr32|mshta') { 'HIGH' } else { 'MEDIUM' }
            $findings += Add-PersistenceFinding -Type 'Service' -Severity $sev -Name $svc.Name -Location $pathName -Description 'Service executable path present' -Details @{
                DisplayName = $svc.DisplayName
                StartMode = $svc.StartMode
                State = $svc.State
                StartName = $svc.StartName
            }
        }
    } catch {}
    return $findings
}

function Get-WMIPersistenceAudit {
    [CmdletBinding()]
    param()

    $findings = @()
    try {
        $consumers = Get-WmiObject -Namespace 'root\subscription' -Class CommandLineEventConsumer -ErrorAction Stop
        foreach ($consumer in $consumers) {
            $cmd = [string]$consumer.CommandLineTemplate
            $sev = if ($cmd -match 'powershell|cmd\.exe|wscript|cscript|mshta|rundll32' -or $cmd -match $script:PersistenceAuditState.SuspiciousPathRegex) { 'HIGH' } else { 'MEDIUM' }
            $findings += Add-PersistenceFinding -Type 'WMIConsumer' -Severity $sev -Name $consumer.Name -Location 'root\subscription:CommandLineEventConsumer' -Description 'WMI command-line event consumer present' -Details @{
                CommandLineTemplate = $cmd
                ExecutablePath = $consumer.ExecutablePath
            }
        }
    } catch {}

    return $findings
}

function Get-ParentChildAnomalies {
    [CmdletBinding()]
    param()

    $findings = @()
    try {
        $procMap = @{}
        Get-CimInstance Win32_Process -ErrorAction Stop | ForEach-Object { $procMap[[int]$_.ProcessId] = $_ }
        foreach ($proc in $procMap.Values) {
            $child = $proc.Name.ToLowerInvariant()
            $ppid = [int]$proc.ParentProcessId
            if (-not $procMap.ContainsKey($ppid)) { continue }
            $parent = $procMap[$ppid].Name.ToLowerInvariant()
            if ($parent -in $script:PersistenceAuditState.SuspiciousParents -and $child -in $script:PersistenceAuditState.SuspiciousChildren) {
                $findings += Add-PersistenceFinding -Type 'ProcessChain' -Severity 'HIGH' -Name $proc.Name -Location ("PID {0} <- PPID {1}" -f $proc.ProcessId, $ppid) -Description 'Suspicious parent-child execution chain' -Details @{
                    ParentName = $procMap[$ppid].Name
                    ChildName = $proc.Name
                    CommandLine = $proc.CommandLine
                    ExecutablePath = $proc.ExecutablePath
                }
            }
        }
    } catch {}
    return $findings
}

function Get-UnsignedProcessImageFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    try {
        Get-CimInstance Win32_Process -ErrorAction Stop | ForEach-Object {
            $path = [string]$_.ExecutablePath
            if (-not $path -or -not (Test-Path $path)) { return }
            try {
                $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
                if ($sig.Status -ne 'Valid') {
                    $sev = if ($path -match $script:PersistenceAuditState.SuspiciousPathRegex) { 'HIGH' } else { 'MEDIUM' }
                    $findings += Add-PersistenceFinding -Type 'UnsignedProcessImage' -Severity $sev -Name $_.Name -Location $path -Description 'Running process image is unsigned or invalidly signed' -Details @{
                        PID = $_.ProcessId
                        SignatureStatus = [string]$sig.Status
                        CommandLine = $_.CommandLine
                    }
                }
            } catch {}
        }
    } catch {}
    return $findings
}

function Get-ExecutablePrivateMemoryFindings {
    [CmdletBinding()]
    param()

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class MemScanNative {
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
    try {
        Get-Process -ErrorAction Stop | ForEach-Object {
            $proc = $_
            $h = [MemScanNative]::OpenProcess($PROCESS_QUERY_INFORMATION -bor $PROCESS_VM_READ, $false, [uint32]$proc.Id)
            if ($h -eq [IntPtr]::Zero) { return }
            try {
                $addr = [IntPtr]::Zero
                while ($true) {
                    $mbi = New-Object MemScanNative+MEMORY_BASIC_INFORMATION
                    $res = [MemScanNative]::VirtualQueryEx($h, $addr, [ref]$mbi, [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type]'MemScanNative+MEMORY_BASIC_INFORMATION'))
                    if ($res -le 0) { break }

                    $protect = [uint32]$mbi.Protect
                    $isExecutable = ($protect -band $PAGE_EXECUTE) -or ($protect -band $PAGE_EXECUTE_READ) -or ($protect -band $PAGE_EXECUTE_READWRITE) -or ($protect -band $PAGE_EXECUTE_WRITECOPY)
                    $isPrivateCommitted = ([uint32]$mbi.State -eq $MEM_COMMIT) -and ([uint32]$mbi.Type -eq $MEM_PRIVATE)

                    if ($isExecutable -and $isPrivateCommitted) {
                        $sev = if ($protect -band $PAGE_EXECUTE_READWRITE) { 'HIGH' } else { 'MEDIUM' }
                        $findings += Add-PersistenceFinding -Type 'ExecutablePrivateMemory' -Severity $sev -Name $proc.ProcessName -Location ("PID {0} @ {1}" -f $proc.Id, $mbi.BaseAddress) -Description 'Committed private executable memory region detected' -Details @{
                            PID = $proc.Id
                            BaseAddress = [string]$mbi.BaseAddress
                            RegionSize = [uint64]$mbi.RegionSize
                            Protect = ('0x{0:X}' -f $protect)
                        }
                    }

                    $next = [Int64]$mbi.BaseAddress + [Int64][UInt64]$mbi.RegionSize
                    if ($next -le 0) { break }
                    $addr = [IntPtr]$next
                }
            } finally {
                [MemScanNative]::CloseHandle($h) | Out-Null
            }
        }
    } catch {}

    return $findings
}

function Get-AlternateDataStreamFindings {
    [CmdletBinding()]
    param(
        [string[]]$Roots = @($env:ProgramData, $env:USERPROFILE)
    )

    $findings = @()
    foreach ($root in $Roots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        try {
            Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $streams = Get-Item -LiteralPath $_.FullName -Stream * -ErrorAction SilentlyContinue
                    foreach ($stream in $streams) {
                        if ($stream.Stream -ne ':$DATA') {
                            $findings += Add-PersistenceFinding -Type 'AlternateDataStream' -Severity 'MEDIUM' -Name $_.Name -Location $_.FullName -Description 'Alternate data stream present' -Details @{
                                Stream = $stream.Stream
                                Length = $stream.Length
                            }
                        }
                    }
                } catch {}
            }
        } catch {}
    }
    return $findings
}

function Get-PersistenceFindings {
    [CmdletBinding()]
    param(
        [switch]$Quick
    )

    $script:PersistenceAuditState.Findings.Clear()

    $null = Get-RunKeyAudit
    $null = Get-StartupFolderAudit
    $null = Get-ScheduledTaskAudit
    $null = Get-ServicePersistenceAudit
    $null = Get-WMIPersistenceAudit
    $null = Get-ParentChildAnomalies
    $null = Get-UnsignedProcessImageFindings
    $null = Get-ExecutablePrivateMemoryFindings

    if (-not $Quick) {
        $null = Get-AlternateDataStreamFindings
    }

    return @($script:PersistenceAuditState.Findings)
}

function Get-PersistenceSummary {
    [CmdletBinding()]
    param(
        [array]$Findings = $(Get-PersistenceFindings)
    )

    $bySeverity = @{}
    $byType = @{}
    foreach ($f in $Findings) {
        $bySeverity[$f.Severity] = 1 + ($bySeverity[$f.Severity] | ForEach-Object { $_ } )
        $byType[$f.Type] = 1 + ($byType[$f.Type] | ForEach-Object { $_ } )
    }

    [pscustomobject]@{
        Total = $Findings.Count
        BySeverity = $bySeverity
        ByType = $byType
        HighSeverity = @($Findings | Where-Object Severity -eq 'HIGH').Count
    }
}

Export-ModuleMember -Function @(
    'Get-RunKeyAudit',
    'Get-StartupFolderAudit',
    'Get-ScheduledTaskAudit',
    'Get-ServicePersistenceAudit',
    'Get-WMIPersistenceAudit',
    'Get-ParentChildAnomalies',
    'Get-UnsignedProcessImageFindings',
    'Get-ExecutablePrivateMemoryFindings',
    'Get-AlternateDataStreamFindings',
    'Get-PersistenceFindings',
    'Get-PersistenceSummary'
)
