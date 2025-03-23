# GhostWhisperBootstrap.ps1
# Master launcher for GhostWhisper Suite (Raven Edition)

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
    "Modules\GhostSeal.ps1",
    "Modules\Phase_Anoint.ps1",
    "Modules\Phase_Bind.ps1",
    "Modules\Phase_Cleanse.ps1",
    "Modules\LinuxPDF_Emu.ps1"
    "Modules\LinuxPDF_Runtime.ps1"
)

foreach ($mod in $modules) {
    if (Test-Path $mod) {
        . $mod
        Write-Host "[+] Loaded: $mod"
    }
    else {
        Write-Warning "[-] Missing module: $mod"
    }
}

# 3. Run Anomaly Detection
Write-Host "[*] Running environment safety scan (AnomalyHunter)..."
Start-AnomalyHunt -Path "$env:SystemDrive\" -Log

# 4. Present Operator Menu
function Show-OperatorMenu {
    Write-Host ""
    Write-Host "GhostWhisper Operator Menu:"
    Write-Host "[1] Start Recon Session (GhostResidency)"
    Write-Host "[2] Run ExorcistMode Cleanup"
    Write-Host "[3] Deploy GhostKey & WraithTap"
    Write-Host "[4] Activate Wormhole Listener"
    Write-Host "[5] Exit"
    Write-Host ""
}

while ($true) {
    Show-OperatorMenu
    $choice = Read-Host "Choose action"

    switch ($choice) {
        "1" {
            Write-Host "[🧠] GhostResidency engagement starting..."
            Start-GhostResidency -Mode "Recon"
        }
        "2" {
            $scanPath = Read-Host "Enter path to scan (default: TEMP)"
            if (-not $scanPath) { $scanPath = $env:TEMP }
            Start-Exorcism -Path $scanPath -Log
        }
        "3" {
            Write-Host "[🔐] Injecting GhostKey..."
            Start-Process -WindowStyle Hidden -FilePath "WraithTap.exe" -ArgumentList "GhostKey.dll"
        }
        "4" {
            Write-Host "[📡] Activating wormhole beacon..."
            . .\Modules\Wormhole.ps1
            Start-WormholeListener
        }
        "5" {
            Write-Host "[✖] Exiting. Ghost sleeps."
            break
        }
        default {
            Write-Warning "Invalid selection. Try again."
        }
    }
}
. "$PSScriptRoot\Modules\Phase_Anoint.ps1"
. "$PSScriptRoot\Modules\Phase_Bind.ps1"
. "$PSScriptRoot\Modules\Phase_Cleanse.ps1"
. "$PSScriptRoot\Modules\LinuxPDF_Emu.ps1"
. "$PSScriptRoot\Modules\LinuxPDF_Runtime.ps1"
. "$PSScriptRoot\Modules\AnamolyHunter.ps1"
. "$PSScriptRoot\Modules\Anamoly_Detector.ps1"
. "$PSScriptRoot\Modules\ExorsistMode.ps1"
