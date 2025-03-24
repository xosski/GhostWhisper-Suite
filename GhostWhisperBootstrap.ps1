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
    "Modules\Anomaly_Detector.ps1", # <---- included here
    "Modules\GhostSeal.ps1",
    "Modules\Phase_Anoint.ps1",
    "Modules\Phase_Bind.ps1",
    "Modules\Phase_Cleanse.ps1",
    "Modules\LinuxPDF_Emu.ps1",
    "Modules\LinuxPDF_Runtime.ps1",
    "Modules\Wormhole.ps1"
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
            # We already loaded Modules\Wormhole.ps1 above
            if (Get-Command -Name Start-WormholeListener -ErrorAction SilentlyContinue) {
                Start-WormholeListener
            }
            else {
                Write-Warning "Function 'Start-WormholeListener' missing from Wormhole module."
            }
        }
        "5" {
            Write-Host "[🔥] Launching GhostLinux VM environment..."

            # e.g. .\LinuxPDF.exe --boot ghost_boot.iso
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
        default {
            Write-Warning "Invalid selection. Try again."
        }
    }
}

Write-Host "[~] GhostWhisperBootstrap session ended."
