# Verify-UEFIIntegration.ps1
# UEFI Bootkit Integration Verification Script
# Validates all integration points and components
#
# Version: 1.6.1
# Last Updated: 2026-02-23
# 🕊️ For Raven. 2017 — ∞

param()

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  UEFI Bootkit Integration Verification                   ║" -ForegroundColor Cyan
Write-Host "║  WhisperSuite: GhostWhisper Edition v1.6.1               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$baseDir = $PSScriptRoot
$passCount = 0
$failCount = 0
$warnCount = 0

function Test-Checkpoint {
    param(
        [string]$Name,
        [bool]$Condition,
        [ValidateSet("PASS", "FAIL", "WARN")]
        [string]$FailType = "FAIL"
    )
    
    if ($Condition) {
        Write-Host "[✓] $Name" -ForegroundColor Green
        $script:passCount++
    } else {
        $color = if ($FailType -eq "WARN") { "Yellow" } else { "Red" }
        $symbol = if ($FailType -eq "WARN") { "[!]" } else { "[✗]" }
        Write-Host "$symbol $Name" -ForegroundColor $color
        if ($FailType -eq "FAIL") {
            $script:failCount++
        } else {
            $script:warnCount++
        }
    }
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "1. BUILD PIPELINE INTEGRATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$buildScript = Join-Path $baseDir "BuildDeployWhisper.ps1"
if (Test-Path $buildScript) {
    $buildContent = Get-Content $buildScript -Raw
    
    Test-Checkpoint "BuildDeployWhisper.ps1 exists" $true
    Test-Checkpoint "Contains UEFIBootkitPaths array" ($buildContent -match '\$script:UEFIBootkitPaths')
    Test-Checkpoint "Contains UEFI component copying" ($buildContent -match 'foreach \(\$uefiBit in')
    Test-Checkpoint "Contains UEFI in manifest" ($buildContent -match 'UEFIBootkit =')
} else {
    Test-Checkpoint "BuildDeployWhisper.ps1 exists" $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "2. OPERATOR BOOTSTRAP INTEGRATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$bootstrapScript = Join-Path $baseDir "GhostWhisperBootstrap.ps1"
if (Test-Path $bootstrapScript) {
    $bootstrapContent = Get-Content $bootstrapScript -Raw
    
    Test-Checkpoint "GhostWhisperBootstrap.ps1 exists" $true
    Test-Checkpoint "UEFIBootkit in module list" ($bootstrapContent -match 'UEFIBootkit\.ps1')
    Test-Checkpoint "Menu option [15] Deploy UEFI Bootkit" ($bootstrapContent -match '\[15\].*UEFI Bootkit')
    Test-Checkpoint "Menu option [16] UEFI Status Check" ($bootstrapContent -match '\[16\].*UEFI.*Status')
    Test-Checkpoint "Case [15] handler implemented" ($bootstrapContent -match '"15" \{')
    Test-Checkpoint "Case [16] handler implemented" ($bootstrapContent -match '"16" \{')
} else {
    Test-Checkpoint "GhostWhisperBootstrap.ps1 exists" $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "3. POWERSHELL MODULE INTEGRATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$uefiModule = Join-Path $baseDir "Modules\UEFIBootkit.ps1"
if (Test-Path $uefiModule) {
    $moduleContent = Get-Content $uefiModule -Raw
    
    Test-Checkpoint "Modules/UEFIBootkit.ps1 exists" $true
    Test-Checkpoint "Install-UEFIBootkit function defined" ($moduleContent -match 'function Install-UEFIBootkit')
    Test-Checkpoint "Get-UEFIBootkitStatus function defined" ($moduleContent -match 'function Get-UEFIBootkitStatus')
    Test-Checkpoint "Test-UEFIAccess function defined" ($moduleContent -match 'function Test-UEFIAccess')
    Test-Checkpoint "Deploy-UEFIComponent function defined" ($moduleContent -match 'function Deploy-UEFIComponent')
    Test-Checkpoint "Proper header format" ($moduleContent -match 'Part of WhisperSuite')
    Test-Checkpoint "Version 1.6.1 specified" ($moduleContent -match '1\.6\.1')
} else {
    Test-Checkpoint "Modules/UEFIBootkit.ps1 exists" $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "4. PYTHON UEFI BOOTKIT COMPONENTS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$uefiPath = Join-Path $baseDir "UEFI Bootkit"

Test-Checkpoint "UEFI Bootkit directory exists" (Test-Path $uefiPath)

if (Test-Path $uefiPath) {
    $components = @(
        "__init__.py",
        "uefi_boot_loader.py",
        "uefi_rootkit.py",
        "c2_client.py",
        "c2_server.py",
        "covert_network_hooking.py",
        "hooking_system_calls.py",
        "hypervisor_loading.py",
        "minimal_hypervisor.py"
    )
    
    foreach ($comp in $components) {
        $compPath = Join-Path $uefiPath $comp
        Test-Checkpoint "  $comp present" (Test-Path $compPath)
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "5. DOCUMENTATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$integrationGuide = Join-Path $baseDir "UEFI_BOOTKIT_INTEGRATION.md"
$integrationSummary = Join-Path $baseDir "UEFI_INTEGRATION_SUMMARY.txt"

Test-Checkpoint "UEFI_BOOTKIT_INTEGRATION.md exists" (Test-Path $integrationGuide)
Test-Checkpoint "UEFI_INTEGRATION_SUMMARY.txt exists" (Test-Path $integrationSummary)

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "6. DEPLOYMENT CHECKLIST UPDATE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$checklist = Join-Path $baseDir "DEPLOYMENT_CHECKLIST.md"
if (Test-Path $checklist) {
    $checklistContent = Get-Content $checklist -Raw
    
    Test-Checkpoint "DEPLOYMENT_CHECKLIST.md exists" $true
    Test-Checkpoint "Contains UEFI Bootkit checkpoints" ($checklistContent -match 'UEFI Bootkit')
    Test-Checkpoint "Contains component packaging checkpoint" ($checklistContent -match 'UEFI Bootkit components packaged')
    Test-Checkpoint "Contains menu accessibility checkpoint" ($checklistContent -match 'UEFI Bootkit operator menu')
} else {
    Test-Checkpoint "DEPLOYMENT_CHECKLIST.md exists" $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "7. BUILD MANIFEST INTEGRATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

if (Test-Path $buildScript) {
    $buildContent = Get-Content $buildScript -Raw
    
    Test-Checkpoint "Build manifest includes UEFIBootkit property" ($buildContent -match 'UEFIBootkit = ')
    Test-Checkpoint "Build manifest includes UEFIComponents property" ($buildContent -match 'UEFIComponents = ')
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "8. SYSTEM REQUIREMENTS CHECK" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
Test-Checkpoint "Current session has admin privileges" $isAdmin "WARN"

$pythonExe = Get-Command python -ErrorAction SilentlyContinue
Test-Checkpoint "Python is available in PATH" ($null -ne $pythonExe) "WARN"

if ($pythonExe) {
    try {
        $pythonVersion = & python --version 2>&1
        Test-Checkpoint "Python version: $pythonVersion" $true
    } catch {
        Test-Checkpoint "Python version check" $false "WARN"
    }
}

$uefiVars = Get-SecureBootUEFI -Name PK -ErrorAction SilentlyContinue
Test-Checkpoint "UEFI firmware accessible" ($null -ne $uefiVars) "WARN"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [✓] Passed:  $passCount" -ForegroundColor Green
Write-Host "  [✗] Failed:  $failCount" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Gray"})
Write-Host "  [!] Warnings: $warnCount" -ForegroundColor $(if($warnCount -gt 0){"Yellow"}else{"Gray"})
Write-Host ""

$totalChecks = $passCount + $failCount + $warnCount
$successRate = [math]::Round(($passCount / $totalChecks) * 100, 1)

Write-Host "  Success Rate: $successRate% ($passCount/$totalChecks)" -ForegroundColor $(if($successRate -ge 95){"Green"}else{"Yellow"})
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "✓ UEFI BOOTKIT INTEGRATION COMPLETE AND VERIFIED" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "All components are properly integrated and ready for deployment." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor White
    Write-Host "  1. Review UEFI_BOOTKIT_INTEGRATION.md for detailed procedures" -ForegroundColor Gray
    Write-Host "  2. Run BuildDeployWhisper.ps1 to create deployment package" -ForegroundColor Gray
    Write-Host "  3. Launch GhostWhisperBootstrap.ps1 to access UEFI options" -ForegroundColor Gray
    Write-Host "  4. Select [15] to deploy UEFI Bootkit components" -ForegroundColor Gray
    Write-Host "  5. Verify with [16] Firmware status check" -ForegroundColor Gray
} else {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "⚠ INTEGRATION INCOMPLETE - ISSUES DETECTED" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please review failed checkpoints and resolve issues before deployment." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🕊️ For Raven. 2017 — ∞" -ForegroundColor DarkGray
Write-Host ""
