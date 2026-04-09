Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
NetworkAudit.ps1
Blue-team network audit module.

Purpose
- Enumerate current network posture for a host
- Review active connections and listening sockets
- Surface suspicious remote endpoints and local listeners
- Collect DNS cache, ARP neighbors, interface/profile state
- Provide a throttled local subnet discovery option

Design notes
- Defensive and triage-oriented
- No packet crafting, no exploitation, no persistence
- Safe to call from GhostShieldBootstrap menu options
#>

$script:NetworkAuditState = [ordered]@{
    Findings = New-Object System.Collections.Generic.List[object]
    SuspiciousProcessNames = @('powershell','cmd','wscript','cscript','mshta','rundll32','regsvr32','certutil','bitsadmin','curl','wget','python')
    SuspiciousPorts = @(4444, 1337, 9001, 31337, 5555, 6666, 8081, 8443)
    SuspiciousPathRegex = '(?i)\\AppData\\|\\Temp\\|\\ProgramData\\|\\Users\\Public\\|\.tmp$|\.dat$'
    BrowserProcesses = @('chrome','msedge','firefox','brave','opera')
}

function Add-NetworkAuditFinding {
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
    $script:NetworkAuditState.Findings.Add($finding) | Out-Null
    return $finding
}

function Get-ConnectionOwnerInfo {
    [CmdletBinding()]
    param(
        [int]$OwningProcess
    )

    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$OwningProcess" -ErrorAction Stop
        return [pscustomobject]@{
            PID = $proc.ProcessId
            Name = $proc.Name
            ExecutablePath = $proc.ExecutablePath
            CommandLine = $proc.CommandLine
            ParentProcessId = $proc.ParentProcessId
        }
    } catch {
        return [pscustomobject]@{
            PID = $OwningProcess
            Name = 'Unknown'
            ExecutablePath = $null
            CommandLine = $null
            ParentProcessId = $null
        }
    }
}

function Get-NetworkConnectionsAudit {
    [CmdletBinding()]
    param(
        [int]$Top = 0
    )

    $connections = @()
    try {
        $connections = @(Get-NetTCPConnection -ErrorAction Stop)
    } catch {
        try {
            $connections = @(Get-NetTCPConnection)
        } catch {
            return @()
        }
    }

    $result = foreach ($conn in $connections) {
        $owner = Get-ConnectionOwnerInfo -OwningProcess ([int]$conn.OwningProcess)
        [pscustomobject]@{
            Protocol = 'TCP'
            State = [string]$conn.State
            LocalAddress = $conn.LocalAddress
            LocalPort = $conn.LocalPort
            RemoteAddress = $conn.RemoteAddress
            RemotePort = $conn.RemotePort
            OwningProcess = [int]$conn.OwningProcess
            ProcessName = $owner.Name
            ExecutablePath = $owner.ExecutablePath
            CommandLine = $owner.CommandLine
        }
    }

    if ($Top -gt 0) {
        return @($result | Select-Object -First $Top)
    }
    return @($result)
}

function Get-ListenerAudit {
    [CmdletBinding()]
    param()

    $findings = @()
    $listeners = @()
    try {
        $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop)
    } catch {
        return @()
    }

    foreach ($listener in $listeners) {
        $owner = Get-ConnectionOwnerInfo -OwningProcess ([int]$listener.OwningProcess)
        $name = ([string]$owner.Name).ToLowerInvariant()
        $path = [string]$owner.ExecutablePath
        $sev = 'LOW'

        if ($listener.LocalPort -in $script:NetworkAuditState.SuspiciousPorts) {
            $sev = 'HIGH'
        } elseif ($name -in $script:NetworkAuditState.SuspiciousProcessNames) {
            $sev = 'HIGH'
        } elseif ($path -and $path -match $script:NetworkAuditState.SuspiciousPathRegex) {
            $sev = 'HIGH'
        } elseif ($listener.LocalAddress -eq '0.0.0.0' -or $listener.LocalAddress -eq '::') {
            $sev = 'MEDIUM'
        }

        if ($sev -ne 'LOW') {
            $findings += Add-NetworkAuditFinding -Type 'Listener' -Severity $sev -Name ($owner.Name) -Location ("{0}:{1}" -f $listener.LocalAddress, $listener.LocalPort) -Description 'Potentially risky listening service detected' -Details @{
                PID = $owner.PID
                ExecutablePath = $owner.ExecutablePath
                CommandLine = $owner.CommandLine
                Port = $listener.LocalPort
                Address = $listener.LocalAddress
            }
        }
    }

    return $findings
}

function Get-SuspiciousRemoteConnectionFindings {
    [CmdletBinding()]
    param()

    $findings = @()
    foreach ($conn in Get-NetworkConnectionsAudit) {
        if ($conn.State -notin @('Established','SynSent','CloseWait')) { continue }
        $name = ([string]$conn.ProcessName).ToLowerInvariant()
        $sev = $null

        if ($conn.RemotePort -in $script:NetworkAuditState.SuspiciousPorts) {
            $sev = 'HIGH'
        } elseif ($name -in $script:NetworkAuditState.SuspiciousProcessNames) {
            $sev = 'MEDIUM'
        } elseif ($conn.ExecutablePath -and $conn.ExecutablePath -match $script:NetworkAuditState.SuspiciousPathRegex) {
            $sev = 'HIGH'
        }

        if ($sev) {
            $findings += Add-NetworkAuditFinding -Type 'RemoteConnection' -Severity $sev -Name $conn.ProcessName -Location ("{0}:{1} -> {2}:{3}" -f $conn.LocalAddress, $conn.LocalPort, $conn.RemoteAddress, $conn.RemotePort) -Description 'Potentially suspicious outbound or active connection' -Details @{
                PID = $conn.OwningProcess
                ExecutablePath = $conn.ExecutablePath
                CommandLine = $conn.CommandLine
                State = $conn.State
            }
        }
    }
    return $findings
}

function Get-DnsCacheAudit {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-DnsClientCache -ErrorAction SilentlyContinue) {
            return @(Get-DnsClientCache -ErrorAction Stop | Select-Object Entry, Name, Data, DataLength, Status, Type)
        }
    } catch {}

    try {
        $raw = & ipconfig /displaydns 2>$null
        return @($raw)
    } catch {
        return @()
    }
}

function Get-ArpNeighborAudit {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue) {
            return @(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop | Select-Object ifIndex, IPAddress, LinkLayerAddress, State, PolicyStore)
        }
    } catch {}

    try {
        return @(& arp -a 2>$null)
    } catch {
        return @()
    }
}

function Get-FirewallProfileAudit {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
            return @(Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, NotifyOnListen, AllowLocalFirewallRules)
        }
    } catch {}
    return @()
}

function Get-NetworkInterfaceAudit {
    [CmdletBinding()]
    param()

    $result = [ordered]@{
        Adapters = @()
        IPs = @()
        Routes = @()
    }

    try {
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $result.Adapters = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed)
        }
    } catch {}

    try {
        if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
            $result.IPs = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -notmatch '^169\.' } | Select-Object InterfaceAlias, IPAddress, PrefixLength)
        }
    } catch {}

    try {
        if (Get-Command Get-NetRoute -ErrorAction SilentlyContinue) {
            $result.Routes = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop | Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric)
        }
    } catch {}

    return [pscustomobject]$result
}

function Invoke-NetworkDiscovery {
    [CmdletBinding()]
    param(
        [int]$TimeoutMs = 400,
        [int]$Throttle = 32,
        [switch]$IncludeHostnames
    )

    $ipObj = $null
    try {
        $ipObj = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notmatch '^169\.' -and $_.IPAddress -notmatch '^127\.' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Select-Object -First 1
    } catch {
        return @()
    }

    if (-not $ipObj) { return @() }

    $ip = $ipObj.IPAddress
    $octets = $ip.Split('.')
    if ($octets.Count -ne 4) { return @() }
    $subnet = "$($octets[0]).$($octets[1]).$($octets[2])"

    $targets = 1..254 | ForEach-Object { "$subnet.$_" }
    $results = New-Object System.Collections.Generic.List[object]
    $jobs = @()

    foreach ($target in $targets) {
        while ((@($jobs | Where-Object { $_.State -eq 'Running' }).Count) -ge $Throttle) {
            Start-Sleep -Milliseconds 150
            foreach ($done in @($jobs | Where-Object { $_.State -ne 'Running' })) {
                try {
                    $r = Receive-Job -Job $done -ErrorAction SilentlyContinue
                    if ($r) { $results.Add($r) | Out-Null }
                } finally {
                    Remove-Job -Job $done -Force -ErrorAction SilentlyContinue
                    $jobs = @($jobs | Where-Object { $_.Id -ne $done.Id })
                }
            }
        }

        $jobs += Start-Job -ScriptBlock {
            param($Address, $TimeoutMs, $IncludeHostnames)
            try {
                $alive = Test-Connection -ComputerName $Address -Count 1 -Quiet -TimeoutSeconds ([Math]::Max([int]([Math]::Ceiling($TimeoutMs / 1000.0)),1))
                if ($alive) {
                    $hostname = $null
                    if ($IncludeHostnames) {
                        try { $hostname = [System.Net.Dns]::GetHostEntry($Address).HostName } catch {}
                    }
                    [pscustomobject]@{ IP = $Address; Alive = $true; Hostname = $hostname }
                }
            } catch {}
        } -ArgumentList $target, $TimeoutMs, $IncludeHostnames.IsPresent
    }

    while ($jobs.Count -gt 0) {
        Start-Sleep -Milliseconds 150
        foreach ($done in @($jobs | Where-Object { $_.State -ne 'Running' })) {
            try {
                $r = Receive-Job -Job $done -ErrorAction SilentlyContinue
                if ($r) { $results.Add($r) | Out-Null }
            } finally {
                Remove-Job -Job $done -Force -ErrorAction SilentlyContinue
                $jobs = @($jobs | Where-Object { $_.Id -ne $done.Id })
            }
        }
    }

    return @($results | Sort-Object IP)
}

function Start-NetworkAudit {
    [CmdletBinding()]
    param(
        [switch]$IncludeDiscovery,
        [int]$TopConnections = 100
    )

    $script:NetworkAuditState.Findings.Clear()

    $connections = Get-NetworkConnectionsAudit -Top $TopConnections
    $listeners = Get-ListenerAudit
    $suspiciousConnections = Get-SuspiciousRemoteConnectionFindings
    $dns = Get-DnsCacheAudit
    $neighbors = Get-ArpNeighborAudit
    $firewallProfiles = Get-FirewallProfileAudit
    $interfaces = Get-NetworkInterfaceAudit
    $discovery = @()

    if ($IncludeDiscovery) {
        $discovery = Invoke-NetworkDiscovery -IncludeHostnames
    }

    [pscustomobject]@{
        Connections = $connections
        ListenerFindings = $listeners
        SuspiciousConnectionFindings = $suspiciousConnections
        DnsCache = $dns
        Neighbors = $neighbors
        FirewallProfiles = $firewallProfiles
        Interfaces = $interfaces
        Discovery = $discovery
        Findings = @($script:NetworkAuditState.Findings)
        Summary = Get-NetworkAuditSummary -Findings @($script:NetworkAuditState.Findings)
    }
}

function Get-NetworkAuditSummary {
    [CmdletBinding()]
    param(
        [array]$Findings = @($script:NetworkAuditState.Findings)
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
    }
}

Export-ModuleMember -Function @(
    'Get-NetworkConnectionsAudit',
    'Get-ListenerAudit',
    'Get-SuspiciousRemoteConnectionFindings',
    'Get-DnsCacheAudit',
    'Get-ArpNeighborAudit',
    'Get-FirewallProfileAudit',
    'Get-NetworkInterfaceAudit',
    'Invoke-NetworkDiscovery',
    'Start-NetworkAudit',
    'Get-NetworkAuditSummary'
)
