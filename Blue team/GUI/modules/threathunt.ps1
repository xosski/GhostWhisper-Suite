Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
ThreatHunt.ps1
Blue-team threat hunting module inspired by the stronger detection themes in Unnamed.py.

Focus areas mirrored from Unnamed.py
- unsigned executables / modules
- suspicious module paths and names
- process hollowing heuristics and unusual parent-child relationships
- suspicious executable memory indicators (RWX/WX/private executable memory)
- shellcode-pattern indicators at a heuristic level
- suspicious network connections
- registry anomaly surfacing where available

Important notes
- Defensive only
- Triage/hunting oriented, not a memory dumper or exploit utility
- Best-effort enumeration: some checks require elevation and may skip inaccessible processes
#>

$script:ThreatHuntState = [ordered]@{
    Findings = New-Object System.Collections.Generic.List[object]
    SuspiciousProcessNames = @('powershell.exe','cmd.exe','wscript.exe','cscript.exe','mshta.exe','rundll32.exe','regsvr32.exe','certutil.exe','bitsadmin.exe')
    SuspiciousModuleNameTokens = @('.tmp','.temp','~','dllhost','svchost','rundll')
    SuspiciousPathRegex = '(?i)\\temp\\|\\tmp\\|\\appdata\\local\\temp\\|\\downloads\\|\\public\\|\\users\\public\\|\\programdata\\'
    SystemProcessNames = @('svchost.exe','lsass.exe','csrss.exe','services.exe','winlogon.exe','smss.exe','wininit.exe','System','Registry')
    SuspiciousPorts = @(4444,1337,5555,6666,8081,8443,9001,31337)
    BrowserParents = @('chrome.exe','msedge.exe','firefox.exe','brave.exe','opera.exe','winword.exe','excel.exe','outlook.exe','acrord32.exe')
    ShellcodePatterns = @(
        @{ Pattern = 'FCE88900000060'; Description = 'Metasploit-style shellcode preamble' },
        @{ Pattern = '4831C04831FF4831D24831F6'; Description = 'Null-free x64 shellcode style register clearing' },
        @{ Pattern = '558BEC83EC'; Description = 'Function prologue with stack adjustment' },
        @{ Pattern = '33C05068'; Description = 'XOR EAX + PUSH sequence common in shellcode' },
        @{ Pattern = 'E900000000'; Description = 'Relative JMP redirector pattern' }
    )
}

function Add-ThreatHuntFinding {
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
    $script:ThreatHuntState.Findings.Add($finding) | Out-Null
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

function Get-ProcessMap {
    [CmdletBinding()]
    param()

    $map = @{}
    foreach ($proc in Get-ProcessInventory) {
        $map[[int]$proc.ProcessId] = $proc
    }
    return $map
}

function Get-ProcessSignatureFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($proc in Get-ProcessInventory) {
        $path = [string]$proc.ExecutablePath
        if (-not $path -or -not (Test-Path $path)) { continue }
        try {
            $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
            if ($sig.Status -ne 'Valid') {
                $sev = if ($path -match $script:ThreatHuntState.SuspiciousPathRegex) { 'HIGH' } else { 'MEDIUM' }
                $findings += Add-ThreatHuntFinding -Type 'UnsignedExecutable' -Severity $sev -Name $proc.Name -Location $path -Description "Process executable is $($sig.Status)" -Details @{
                    PID = $proc.ProcessId
                    CommandLine = $proc.CommandLine
                    SignatureStatus = [string]$sig.Status
                }
            }
        } catch {}
    }
    return $findings
}

function Get-ModuleInventory {
    [CmdletBinding()]
    param(
        [System.Diagnostics.Process]$Process
    )

    $mods = @()
    try {
        foreach ($module in $Process.Modules) {
            $mods += [pscustomobject]@{
                Name = $module.ModuleName
                Path = $module.FileName
                BaseAddress = [string]$module.BaseAddress
                Size = $module.ModuleMemorySize
            }
        }
    } catch {}
    return $mods
}

function Get-ModuleAnomalyFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        $modules = Get-ModuleInventory -Process $proc
        foreach ($module in $modules) {
            $modulePath = [string]$module.Path
            $moduleName = ([string]$module.Name).ToLowerInvariant()
            if (-not $modulePath) { continue }

            if ($modulePath.ToLowerInvariant() -match $script:ThreatHuntState.SuspiciousPathRegex) {
                $findings += Add-ThreatHuntFinding -Type 'SuspiciousModuleLocation' -Severity 'HIGH' -Name $proc.ProcessName -Location $modulePath -Description 'Module loaded from unusual location' -Details @{
                    PID = $proc.Id
                    ModuleName = $module.Name
                    BaseAddress = $module.BaseAddress
                    Size = $module.Size
                }
            }

            if ($script:ThreatHuntState.SuspiciousModuleNameTokens | Where-Object { $moduleName -like "*$_*" }) {
                $findings += Add-ThreatHuntFinding -Type 'SuspiciousModuleName' -Severity 'MEDIUM' -Name $proc.ProcessName -Location $modulePath -Description 'Module name contains suspicious token' -Details @{
                    PID = $proc.Id
                    ModuleName = $module.Name
                }
            }

            try {
                $sig = Get-AuthenticodeSignature -FilePath $modulePath -ErrorAction Stop
                if ($sig.Status -ne 'Valid' -and -not $modulePath.ToLowerInvariant().StartsWith('c:\windows\system32\')) {
                    $findings += Add-ThreatHuntFinding -Type 'UnsignedModule' -Severity 'MEDIUM' -Name $proc.ProcessName -Location $modulePath -Description "Module $($module.Name) is $($sig.Status)" -Details @{
                        PID = $proc.Id
                        ModuleName = $module.Name
                        SignatureStatus = [string]$sig.Status
                    }
                }
            } catch {}
        }
    }
    return $findings
}

function Get-ParentChildAnomalyFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    $map = Get-ProcessMap

    $legitimate = @{
        'smss.exe' = @('System','4')
        'csrss.exe' = @('smss.exe','wininit.exe')
        'wininit.exe' = @('smss.exe')
        'services.exe' = @('wininit.exe')
        'lsass.exe' = @('wininit.exe')
        'winlogon.exe' = @('smss.exe')
    }

    foreach ($proc in $map.Values) {
        $pid = [int]$proc.ProcessId
        $ppid = [int]$proc.ParentProcessId
        $name = ([string]$proc.Name).ToLowerInvariant()
        if (-not $map.ContainsKey($ppid)) { continue }
        $parent = $map[$ppid]
        $parentName = ([string]$parent.Name).ToLowerInvariant()

        if ($script:ThreatHuntState.BrowserParents -contains $parentName -and $script:ThreatHuntState.SuspiciousProcessNames -contains $name) {
            $findings += Add-ThreatHuntFinding -Type 'SuspiciousParentChild' -Severity 'HIGH' -Name $proc.Name -Location ("PID {0} <- PPID {1}" -f $pid, $ppid) -Description 'Suspicious parent-child relationship' -Details @{
                ParentName = $parent.Name
                ParentPID = $parent.ProcessId
                ChildName = $proc.Name
                ChildPID = $proc.ProcessId
                CommandLine = $proc.CommandLine
            }
            continue
        }

        if ($legitimate.ContainsKey($name)) {
            $validParents = @($legitimate[$name])
            if ($parentName -notin ($validParents | ForEach-Object { $_.ToLowerInvariant() }) -and ([string]$parent.ProcessId) -notin $validParents) {
                $findings += Add-ThreatHuntFinding -Type 'SystemProcessTreeAnomaly' -Severity 'MEDIUM' -Name $proc.Name -Location ("PID {0} <- PPID {1}" -f $pid, $ppid) -Description 'System process has unusual parent relationship' -Details @{
                    ParentName = $parent.Name
                    ParentPID = $parent.ProcessId
                    ChildName = $proc.Name
                    ChildPID = $proc.ProcessId
                }
            }
        }
    }

    return $findings
}

function Get-PathDiscrepancyFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($proc in Get-ProcessInventory) {
        $path = [string]$proc.ExecutablePath
        if (-not $path) { continue }
        if (($proc.Name -in $script:ThreatHuntState.SystemProcessNames) -and ($path -notmatch '(?i)^C:\\Windows\\')) {
            $findings += Add-ThreatHuntFinding -Type 'ExecutablePathDiscrepancy' -Severity 'HIGH' -Name $proc.Name -Location $path -Description 'Protected/system process is running from an unusual path' -Details @{
                PID = $proc.ProcessId
                CommandLine = $proc.CommandLine
            }
        }
    }
    return $findings
}

function Get-SuspiciousNetworkFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) { return @() }

    $procIndex = @{}
    foreach ($p in Get-ProcessInventory) { $procIndex[[int]$p.ProcessId] = $p }

    try {
        foreach ($conn in Get-NetTCPConnection -ErrorAction Stop) {
            $pid = [int]$conn.OwningProcess
            if (-not $procIndex.ContainsKey($pid)) { continue }
            $proc = $procIndex[$pid]
            $procName = ([string]$proc.Name).ToLowerInvariant()
            $sev = $null

            if ($conn.RemotePort -in $script:ThreatHuntState.SuspiciousPorts) {
                $sev = 'HIGH'
            } elseif ($procName -in ($script:ThreatHuntState.SuspiciousProcessNames | ForEach-Object { $_.ToLowerInvariant() })) {
                $sev = 'MEDIUM'
            } elseif ($proc.ExecutablePath -and ([string]$proc.ExecutablePath) -match $script:ThreatHuntState.SuspiciousPathRegex) {
                $sev = 'HIGH'
            }

            if ($sev) {
                $findings += Add-ThreatHuntFinding -Type 'SuspiciousNetworkConnection' -Severity $sev -Name $proc.Name -Location ("{0}:{1} -> {2}:{3}" -f $conn.LocalAddress, $conn.LocalPort, $conn.RemoteAddress, $conn.RemotePort) -Description 'Potentially suspicious network connection detected' -Details @{
                    PID = $pid
                    State = [string]$conn.State
                    ExecutablePath = $proc.ExecutablePath
                    CommandLine = $proc.CommandLine
                }
            }
        }
    } catch {}

    return $findings
}

function Get-RegistryAnomalyFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    $suspiciousLocations = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\AppInit_DLLs',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    )

    foreach ($path in $suspiciousLocations) {
        try {
            if (-not (Test-Path $path)) { continue }
            $item = Get-ItemProperty -Path $path -ErrorAction Stop
            foreach ($prop in $item.PSObject.Properties) {
                if ($prop.Name -match '^PS') { continue }
                $value = [string]$prop.Value
                $sev = if ($value -match $script:ThreatHuntState.SuspiciousPathRegex -or $value -match 'powershell|mshta|rundll32|regsvr32|wscript|cscript|cmd\.exe') { 'HIGH' } else { 'MEDIUM' }
                $findings += Add-ThreatHuntFinding -Type 'RegistryAnomaly' -Severity $sev -Name $prop.Name -Location $path -Description 'Suspicious registry-backed execution or persistence surface' -Details @{
                    Value = $value
                }
            }
        } catch {}
    }

    return $findings
}

function Get-ExecutableMemoryFindings {
    [CmdletBinding()]
    param()

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ThreatHuntNative {
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
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@ -ErrorAction SilentlyContinue | Out-Null

    $PROCESS_QUERY_INFORMATION = 0x0400
    $PROCESS_VM_READ = 0x0010
    $MEM_COMMIT = 0x1000
    $MEM_PRIVATE = 0x20000
    $PAGE_NOACCESS = 0x01
    $PAGE_READONLY = 0x02
    $PAGE_READWRITE = 0x04
    $PAGE_WRITECOPY = 0x08
    $PAGE_EXECUTE = 0x10
    $PAGE_EXECUTE_READ = 0x20
    $PAGE_EXECUTE_READWRITE = 0x40
    $PAGE_EXECUTE_WRITECOPY = 0x80
    $PAGE_TARGETS_INVALID = 0x40000000
    $PAGE_TARGETS_NO_UPDATE = 0x40000000

    $findings = @()

    foreach ($proc in Get-Process -ErrorAction SilentlyContinue) {
        $handle = [ThreatHuntNative]::OpenProcess($PROCESS_QUERY_INFORMATION -bor $PROCESS_VM_READ, $false, [uint32]$proc.Id)
        if ($handle -eq [IntPtr]::Zero) { continue }

        try {
            $address = [IntPtr]::Zero
            while ($true) {
                $mbi = New-Object ThreatHuntNative+MEMORY_BASIC_INFORMATION
                $result = [ThreatHuntNative]::VirtualQueryEx($handle, $address, [ref]$mbi, [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type]'ThreatHuntNative+MEMORY_BASIC_INFORMATION'))
                if ($result -le 0) { break }

                $protect = [uint32]$mbi.Protect
                $regionSize = [uint64]$mbi.RegionSize
                $baseAddress = [string]$mbi.BaseAddress
                $isExecutable = ($protect -band $PAGE_EXECUTE) -or ($protect -band $PAGE_EXECUTE_READ) -or ($protect -band $PAGE_EXECUTE_READWRITE) -or ($protect -band $PAGE_EXECUTE_WRITECOPY)
                $isPrivateCommitted = ([uint32]$mbi.State -eq $MEM_COMMIT) -and ([uint32]$mbi.Type -eq $MEM_PRIVATE)

                if (($protect -band $PAGE_NOACCESS) -and ($proc.ProcessName.ToLowerInvariant() -in ($script:ThreatHuntState.SystemProcessNames | ForEach-Object { $_.ToLowerInvariant() }))) {
                    $findings += Add-ThreatHuntFinding -Type 'SuspiciousMemoryProtection' -Severity 'HIGH' -Name $proc.ProcessName -Location ("Memory region at {0}, size: {1}" -f $baseAddress, $regionSize) -Description 'NOACCESS memory in system process (potential hidden code)' -Details @{ PID = $proc.Id; Protect = ('0x{0:X}' -f $protect) }
                }

                if (($protect -band $PAGE_WRITECOPY) -and (($protect -band $PAGE_EXECUTE) -or ($protect -band $PAGE_EXECUTE_READ) -or ($protect -band $PAGE_EXECUTE_WRITECOPY))) {
                    $findings += Add-ThreatHuntFinding -Type 'SuspiciousMemoryProtection' -Severity 'HIGH' -Name $proc.ProcessName -Location ("Memory region at {0}, size: {1}" -f $baseAddress, $regionSize) -Description 'Executable WRITECOPY memory' -Details @{ PID = $proc.Id; Protect = ('0x{0:X}' -f $protect) }
                }

                if ($protect -band $PAGE_EXECUTE_READWRITE) {
                    $findings += Add-ThreatHuntFinding -Type 'SuspiciousMemoryProtection' -Severity 'HIGH' -Name $proc.ProcessName -Location ("Memory region at {0}, size: {1}" -f $baseAddress, $regionSize) -Description 'RWX memory region detected' -Details @{ PID = $proc.Id; Protect = ('0x{0:X}' -f $protect) }
                }

                if (($protect -band $PAGE_EXECUTE) -and ($protect -band $PAGE_READWRITE) -and -not ($protect -band $PAGE_READONLY)) {
                    $findings += Add-ThreatHuntFinding -Type 'HighRiskMemoryProtection' -Severity 'HIGH' -Name $proc.ProcessName -Location ("Memory region at {0}, size: {1}" -f $baseAddress, $regionSize) -Description 'Write+Execute memory without read permission' -Details @{ PID = $proc.Id; Protect = ('0x{0:X}' -f $protect) }
                }

                if ($protect -band $PAGE_TARGETS_INVALID) {
                    $sev = if ($proc.ProcessName.ToLowerInvariant() -in ($script:ThreatHuntState.SystemProcessNames | ForEach-Object { $_.ToLowerInvariant() })) { 'HIGH' } else { 'MEDIUM' }
                    $findings += Add-ThreatHuntFinding -Type 'ControlFlowGuardBypass' -Severity $sev -Name $proc.ProcessName -Location ("Memory region at {0}, size: {1}" -f $baseAddress, $regionSize) -Description 'PAGE_TARGETS_INVALID / CFG bypass style protection flag detected' -Details @{ PID = $proc.Id; Protect = ('0x{0:X}' -f $protect) }
                }

                if ($isExecutable -and $isPrivateCommitted) {
                    $sev = if ($protect -band $PAGE_EXECUTE_READWRITE) { 'HIGH' } else { 'MEDIUM' }
                    $detail = @{ PID = $proc.Id; Protect = ('0x{0:X}' -f $protect); BaseAddress = $baseAddress; RegionSize = $regionSize }
                    $findings += Add-ThreatHuntFinding -Type 'ExecutablePrivateMemory' -Severity $sev -Name $proc.ProcessName -Location ("Memory region at {0}, size: {1}" -f $baseAddress, $regionSize) -Description 'Committed private executable memory region detected' -Details $detail

                    if ($regionSize -ge 64) {
                        try {
                            $sampleLength = [Math]::Min([int]$regionSize, 512)
                            $buffer = New-Object byte[] $sampleLength
                            $bytesRead = [IntPtr]::Zero
                            $ok = [ThreatHuntNative]::ReadProcessMemory($handle, [IntPtr]$mbi.BaseAddress, $buffer, $sampleLength, [ref]$bytesRead)
                            if ($ok -and $bytesRead -ne [IntPtr]::Zero) {
                                $hex = ([System.BitConverter]::ToString($buffer)).Replace('-','')
                                foreach ($pattern in $script:ThreatHuntState.ShellcodePatterns) {
                                    if ($hex -like "*$($pattern.Pattern)*") {
                                        $findings += Add-ThreatHuntFinding -Type 'ShellcodePattern' -Severity 'HIGH' -Name $proc.ProcessName -Location ("Memory region at {0}" -f $baseAddress) -Description $pattern.Description -Details @{ PID = $proc.Id; BaseAddress = $baseAddress; SampleLength = $sampleLength }
                                    }
                                }
                            }
                        } catch {}
                    }
                }

                $next = [Int64]$mbi.BaseAddress + [Int64][UInt64]$mbi.RegionSize
                if ($next -le 0) { break }
                $address = [IntPtr]$next
            }
        } finally {
            [ThreatHuntNative]::CloseHandle($handle) | Out-Null
        }
    }

    return $findings
}

function Get-ProcessHollowingHeuristicFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    $map = Get-ProcessMap

    foreach ($proc in $map.Values) {
        $pid = [int]$proc.ProcessId
        $name = [string]$proc.Name
        $path = [string]$proc.ExecutablePath
        $ppid = [int]$proc.ParentProcessId
        $parentName = if ($map.ContainsKey($ppid)) { [string]$map[$ppid].Name } else { 'Unknown' }

        $details = @()
        if ($parentName -and ($script:ThreatHuntState.BrowserParents -contains $parentName.ToLowerInvariant()) -and ($script:ThreatHuntState.SuspiciousProcessNames -contains $name.ToLowerInvariant())) {
            $details += 'Suspicious parent-child relationship'
        }
        if ($path -and ($name.ToLowerInvariant() -in ($script:ThreatHuntState.SystemProcessNames | ForEach-Object { $_.ToLowerInvariant() })) -and ($path -notmatch '(?i)^C:\\Windows\\')) {
            $details += 'Executable path discrepancy detected'
        }
        if (-not $path -and ($name.ToLowerInvariant() -notin @('system','registry'))) {
            $details += 'Executable path unavailable or denied unexpectedly'
        }

        if ($details.Count -gt 0) {
            $findings += Add-ThreatHuntFinding -Type 'ProcessHollowingHeuristic' -Severity 'HIGH' -Name $name -Location ("PID {0}" -f $pid) -Description 'Suspected process hollowing or image replacement indicators' -Details @{
                PID = $pid
                ParentPID = $ppid
                ParentName = $parentName
                ExecutablePath = $path
                Indicators = $details
                DetectionMethod = 'heuristic'
            }
        }
    }

    return $findings
}

function Get-HuntSummary {
    [CmdletBinding()]
    param(
        [array]$Findings = @($script:ThreatHuntState.Findings)
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
        MediumSeverity = @($Findings | Where-Object Severity -eq 'MEDIUM').Count
        LowSeverity = @($Findings | Where-Object Severity -eq 'LOW').Count
        BySeverity = $bySeverity
        ByType = $byType
    }
}

function Start-ThreatHunt {
    [CmdletBinding()]
    param(
        [switch]$Quick
    )

    $script:ThreatHuntState.Findings.Clear()

    $null = Get-ProcessSignatureFindings
    $null = Get-ModuleAnomalyFindings
    $null = Get-ParentChildAnomalyFindings
    $null = Get-PathDiscrepancyFindings
    $null = Get-SuspiciousNetworkFindings
    $null = Get-RegistryAnomalyFindings
    $null = Get-ProcessHollowingHeuristicFindings

    if (-not $Quick) {
        $null = Get-ExecutableMemoryFindings
    }

    [pscustomobject]@{
        Findings = @($script:ThreatHuntState.Findings)
        Summary = Get-HuntSummary -Findings @($script:ThreatHuntState.Findings)
    }
}

Export-ModuleMember -Function @(
    'Get-ProcessSignatureFindings',
    'Get-ModuleAnomalyFindings',
    'Get-ParentChildAnomalyFindings',
    'Get-PathDiscrepancyFindings',
    'Get-SuspiciousNetworkFindings',
    'Get-RegistryAnomalyFindings',
    'Get-ExecutableMemoryFindings',
    'Get-ProcessHollowingHeuristicFindings',
    'Get-HuntSummary',
    'Start-ThreatHunt'
)