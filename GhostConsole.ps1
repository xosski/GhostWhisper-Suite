# GhostConsole.ps1
# Modern WPF-based GUI Console for GhostWhisper Suite (Raven Edition)
# Provides a unified operator interface with real-time feedback

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Verify admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    [System.Windows.MessageBox]::Show("GhostConsole requires Administrator privileges.`nPlease restart as Administrator.", "GhostWhisper Suite", "OK", "Warning")
    exit
}

$script:SuiteRoot = $PSScriptRoot
$script:LogBuffer = [System.Collections.ArrayList]::new()

# XAML Definition for the UI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GhostWhisper Suite - Operator Console" 
        Height="720" Width="1100"
        WindowStartupLocation="CenterScreen"
        Background="#1a1a2e" Foreground="#eaeaea"
        ResizeMode="CanResizeWithGrip">
    
    <Window.Resources>
        <Style x:Key="GhostButton" TargetType="Button">
            <Setter Property="Background" Value="#16213e"/>
            <Setter Property="Foreground" Value="#e94560"/>
            <Setter Property="BorderBrush" Value="#e94560"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="15,10"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#e94560"/>
                                <Setter Property="Foreground" Value="#1a1a2e"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <Style x:Key="CategoryButton" TargetType="Button">
            <Setter Property="Background" Value="#0f3460"/>
            <Setter Property="Foreground" Value="#00fff5"/>
            <Setter Property="BorderBrush" Value="#00fff5"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="Margin" Value="3"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#00fff5"/>
                                <Setter Property="Foreground" Value="#0f3460"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <Style x:Key="StatusLabel" TargetType="Label">
            <Setter Property="Foreground" Value="#888"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="11"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <Border Grid.Row="0" Background="#0f3460" Padding="15">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                
                <StackPanel Grid.Column="0">
                    <TextBlock Text="GhostWhisper Suite" FontSize="24" FontWeight="Bold" 
                               Foreground="#e94560" FontFamily="Consolas"/>
                    <TextBlock Text="Raven Edition - Multi-Vector Exploitation Platform" 
                               FontSize="11" Foreground="#888" FontFamily="Consolas" Margin="0,2,0,0"/>
                </StackPanel>
                
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Ellipse Width="10" Height="10" Fill="#00ff00" Margin="5,0" Name="StatusIndicator"/>
                    <TextBlock Text="READY" Name="StatusText" Foreground="#00ff00" 
                               FontFamily="Consolas" FontSize="12" VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </Border>
        
        <!-- Category Tabs -->
        <Border Grid.Row="1" Background="#16213e" Padding="10,5">
            <StackPanel Orientation="Horizontal">
                <Button Content="Memory Operations" Style="{StaticResource CategoryButton}" Name="TabMemory"/>
                <Button Content="Kernel Access" Style="{StaticResource CategoryButton}" Name="TabKernel"/>
                <Button Content="Browser Exploitation" Style="{StaticResource CategoryButton}" Name="TabBrowser"/>
                <Button Content="Network/BLE" Style="{StaticResource CategoryButton}" Name="TabNetwork"/>
                <Button Content="Utilities" Style="{StaticResource CategoryButton}" Name="TabUtilities"/>
                <Button Content="Cleanup" Style="{StaticResource CategoryButton}" Name="TabCleanup"/>
            </StackPanel>
        </Border>
        
        <!-- Main Content Area -->
        <Grid Grid.Row="2" Margin="10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="280"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            
            <!-- Operations Panel -->
            <Border Grid.Column="0" Background="#16213e" CornerRadius="5" Padding="10" Margin="0,0,5,0">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Name="OperationsPanel">
                        <TextBlock Text="OPERATIONS" Foreground="#e94560" FontFamily="Consolas" 
                                   FontWeight="Bold" Margin="0,0,0,10"/>
                        
                        <!-- Memory Operations (Default View) -->
                        <StackPanel Name="MemoryOps">
                            <Button Content="Start Recon Session" Style="{StaticResource GhostButton}" Name="BtnRecon"/>
                            <Button Content="Deploy GhostKey + WraithTap" Style="{StaticResource GhostButton}" Name="BtnGhostKey"/>
                            <Button Content="GhostResidency Handler" Style="{StaticResource GhostButton}" Name="BtnResidency"/>
                            <Button Content="Process Hollowing" Style="{StaticResource GhostButton}" Name="BtnHollow"/>
                            <Button Content="Polymorph Build" Style="{StaticResource GhostButton}" Name="BtnPolymorph"/>
                        </StackPanel>
                        
                        <!-- Kernel Operations -->
                        <StackPanel Name="KernelOps" Visibility="Collapsed">
                            <Button Content="Deploy GhostKernel" Style="{StaticResource GhostButton}" Name="BtnKernel"/>
                            <Button Content="Read Disk Sector" Style="{StaticResource GhostButton}" Name="BtnReadSector"/>
                            <Button Content="USB Gadget Control" Style="{StaticResource GhostButton}" Name="BtnUSBGadget"/>
                            <Button Content="Launch Linux VM" Style="{StaticResource GhostButton}" Name="BtnLinuxVM"/>
                        </StackPanel>
                        
                        <!-- Browser Operations -->
                        <StackPanel Name="BrowserOps" Visibility="Collapsed">
                            <Button Content="Deploy GhostCore Extension" Style="{StaticResource GhostButton}" Name="BtnGhostCore"/>
                            <Button Content="Deploy Discord Injection" Style="{StaticResource GhostButton}" Name="BtnDiscord"/>
                            <Button Content="Deploy GhostSurface" Style="{StaticResource GhostButton}" Name="BtnGhostSurface"/>
                            <Button Content="Build Native Host" Style="{StaticResource GhostButton}" Name="BtnNativeHost"/>
                            <Button Content="Chrome RDP Install" Style="{StaticResource GhostButton}" Name="BtnChromeRDP"/>
                        </StackPanel>
                        
                        <!-- Network Operations -->
                        <StackPanel Name="NetworkOps" Visibility="Collapsed">
                            <Button Content="BLE Trigger Activation" Style="{StaticResource GhostButton}" Name="BtnBLETrigger"/>
                            <Button Content="Activate Wormhole" Style="{StaticResource GhostButton}" Name="BtnWormhole"/>
                            <Button Content="SSH Brute Force" Style="{StaticResource GhostButton}" Name="BtnSSHBrute"/>
                            <Button Content="Bluetooth Scanner" Style="{StaticResource GhostButton}" Name="BtnBluetooth"/>
                            <Button Content="FTP Automation" Style="{StaticResource GhostButton}" Name="BtnFTP"/>
                            <Button Content="OBEX Brute Force" Style="{StaticResource GhostButton}" Name="BtnOBEX"/>
                        </StackPanel>
                        
                        <!-- Utility Operations -->
                        <StackPanel Name="UtilityOps" Visibility="Collapsed">
                            <Button Content="Anomaly Hunter" Style="{StaticResource GhostButton}" Name="BtnAnomalyHunter"/>
                            <Button Content="ExorcistMode Cleanup" Style="{StaticResource GhostButton}" Name="BtnExorcist"/>
                            <Button Content="GhostSeal Encrypt" Style="{StaticResource GhostButton}" Name="BtnSealEncrypt"/>
                            <Button Content="GhostSeal Decrypt" Style="{StaticResource GhostButton}" Name="BtnSealDecrypt"/>
                            <Button Content="View Logs" Style="{StaticResource GhostButton}" Name="BtnViewLogs"/>
                            <Button Content="Build Suite" Style="{StaticResource GhostButton}" Name="BtnBuildSuite"/>
                        </StackPanel>
                        
                        <!-- Cleanup Operations -->
                        <StackPanel Name="CleanupOps" Visibility="Collapsed">
                            <Button Content="SilentBloom (Full Cleanup)" Style="{StaticResource GhostButton}" Name="BtnSilentBloom"/>
                            <Button Content="Clear Ghost Logs" Style="{StaticResource GhostButton}" Name="BtnClearLogs"/>
                            <Button Content="Phase: Anoint" Style="{StaticResource GhostButton}" Name="BtnAnoint"/>
                            <Button Content="Phase: Bind" Style="{StaticResource GhostButton}" Name="BtnBind"/>
                            <Button Content="Phase: Cleanse" Style="{StaticResource GhostButton}" Name="BtnCleanse"/>
                        </StackPanel>
                    </StackPanel>
                </ScrollViewer>
            </Border>
            
            <!-- Console Output Panel -->
            <Border Grid.Column="1" Background="#0d0d1a" CornerRadius="5" Padding="10" Margin="5,0,0,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="CONSOLE OUTPUT" Foreground="#00fff5" FontFamily="Consolas" FontWeight="Bold"/>
                        <Button Grid.Column="1" Content="Clear" Style="{StaticResource CategoryButton}" Name="BtnClearConsole"/>
                    </Grid>
                    
                    <ScrollViewer Grid.Row="1" Name="ConsoleScroller" VerticalScrollBarVisibility="Auto">
                        <TextBlock Name="ConsoleOutput" TextWrapping="Wrap" FontFamily="Consolas" 
                                   FontSize="11" Foreground="#00ff00" Background="Transparent"/>
                    </ScrollViewer>
                    
                    <Grid Grid.Row="2" Margin="0,10,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox Name="CommandInput" Background="#16213e" Foreground="#eaeaea" 
                                 BorderBrush="#e94560" BorderThickness="1" Padding="8" 
                                 FontFamily="Consolas" FontSize="12"/>
                        <Button Grid.Column="1" Content="Execute" Style="{StaticResource GhostButton}" 
                                Name="BtnExecute" Margin="5,0,0,0"/>
                    </Grid>
                </Grid>
            </Border>
        </Grid>
        
        <!-- Footer Status Bar -->
        <Border Grid.Row="3" Background="#0f3460" Padding="10,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                
                <TextBlock Grid.Column="0" Name="FooterStatus" Text="Ready for operations" 
                           Foreground="#888" FontFamily="Consolas" FontSize="11"/>
                <TextBlock Grid.Column="1" Text="GhostTag:" Foreground="#888" FontFamily="Consolas" 
                           FontSize="11" Margin="20,0,5,0"/>
                <TextBox Grid.Column="2" Name="GhostTagInput" Text="Gx01" Width="80" 
                         Background="#16213e" Foreground="#e94560" BorderBrush="#e94560" 
                         FontFamily="Consolas" FontSize="11" Padding="5,2"/>
                <TextBlock Grid.Column="3" Text="  For Raven" Foreground="#e94560" 
                           FontFamily="Consolas" FontSize="11" FontStyle="Italic"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Create window from XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI elements
$elements = @{}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    $elements[$_.Name] = $window.FindName($_.Name)
}

# Console output helper
function Write-Console {
    param(
        [string]$Message,
        [string]$Color = "#00ff00"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullMessage = "[$timestamp] $Message`n"
    
    $window.Dispatcher.Invoke([action]{
        $elements.ConsoleOutput.Inlines.Add((New-Object System.Windows.Documents.Run $fullMessage))
        $elements.ConsoleScroller.ScrollToEnd()
    })
    
    $script:LogBuffer.Add($fullMessage) | Out-Null
}

function Set-Status {
    param(
        [string]$Status,
        [string]$Color = "#00ff00"
    )
    
    $window.Dispatcher.Invoke([action]{
        $elements.StatusText.Text = $Status.ToUpper()
        $elements.StatusText.Foreground = $Color
        $elements.StatusIndicator.Fill = $Color
        $elements.FooterStatus.Text = $Status
    })
}

# Category tab handlers
$elements.TabMemory.Add_Click({ 
    @("MemoryOps", "KernelOps", "BrowserOps", "NetworkOps", "UtilityOps", "CleanupOps") | ForEach-Object {
        $elements.$_.Visibility = if ($_ -eq "MemoryOps") { "Visible" } else { "Collapsed" }
    }
    Write-Console "Switched to Memory Operations"
})

$elements.TabKernel.Add_Click({ 
    @("MemoryOps", "KernelOps", "BrowserOps", "NetworkOps", "UtilityOps", "CleanupOps") | ForEach-Object {
        $elements.$_.Visibility = if ($_ -eq "KernelOps") { "Visible" } else { "Collapsed" }
    }
    Write-Console "Switched to Kernel Access"
})

$elements.TabBrowser.Add_Click({ 
    @("MemoryOps", "KernelOps", "BrowserOps", "NetworkOps", "UtilityOps", "CleanupOps") | ForEach-Object {
        $elements.$_.Visibility = if ($_ -eq "BrowserOps") { "Visible" } else { "Collapsed" }
    }
    Write-Console "Switched to Browser Exploitation"
})

$elements.TabNetwork.Add_Click({ 
    @("MemoryOps", "KernelOps", "BrowserOps", "NetworkOps", "UtilityOps", "CleanupOps") | ForEach-Object {
        $elements.$_.Visibility = if ($_ -eq "NetworkOps") { "Visible" } else { "Collapsed" }
    }
    Write-Console "Switched to Network/BLE Operations"
})

$elements.TabUtilities.Add_Click({ 
    @("MemoryOps", "KernelOps", "BrowserOps", "NetworkOps", "UtilityOps", "CleanupOps") | ForEach-Object {
        $elements.$_.Visibility = if ($_ -eq "UtilityOps") { "Visible" } else { "Collapsed" }
    }
    Write-Console "Switched to Utilities"
})

$elements.TabCleanup.Add_Click({ 
    @("MemoryOps", "KernelOps", "BrowserOps", "NetworkOps", "UtilityOps", "CleanupOps") | ForEach-Object {
        $elements.$_.Visibility = if ($_ -eq "CleanupOps") { "Visible" } else { "Collapsed" }
    }
    Write-Console "Switched to Cleanup Operations"
})

# Clear console
$elements.BtnClearConsole.Add_Click({
    $elements.ConsoleOutput.Inlines.Clear()
    Write-Console "Console cleared"
})

# Execute custom command
$elements.BtnExecute.Add_Click({
    $cmd = $elements.CommandInput.Text
    if ($cmd) {
        Write-Console "> $cmd"
        try {
            Set-Status "Executing..." "#ffcc00"
            $result = Invoke-Expression $cmd 2>&1
            if ($result) { 
                $result | ForEach-Object { Write-Console $_.ToString() }
            }
            Set-Status "Ready" "#00ff00"
        }
        catch {
            Write-Console "ERROR: $_" 
            Set-Status "Error" "#ff0000"
        }
        $elements.CommandInput.Text = ""
    }
})

$elements.CommandInput.Add_KeyDown({
    if ($_.Key -eq "Return") {
        $elements.BtnExecute.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    }
})

# Memory Operations
$elements.BtnRecon.Add_Click({
    Write-Console "Starting GhostResidency Recon Session..."
    Set-Status "Recon Active" "#ffcc00"
    $modPath = Join-Path $script:SuiteRoot "Modules\GhostResidency.ps1"
    if (-not (Test-Path $modPath)) { $modPath = Join-Path $script:SuiteRoot "GhostResidency.ps1" }
    if (Test-Path $modPath) {
        . $modPath
        if (Get-Command -Name Start-GhostResidency -ErrorAction SilentlyContinue) {
            Start-GhostResidency -Mode "Recon"
            Write-Console "GhostResidency session active"
        } else {
            Write-Console "Function Start-GhostResidency not found in module"
        }
    } else {
        Write-Console "GhostResidency module not found"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnGhostKey.Add_Click({
    Write-Console "Deploying GhostKey + WraithTap..."
    Set-Status "Injecting" "#e94560"
    $ghostDll = Join-Path $script:SuiteRoot "bin\x64\Debug\GhostKey.dll"
    $wraithTap = Join-Path $script:SuiteRoot "bin\x64\Debug\WraithTap.exe"
    
    if (-not (Test-Path $ghostDll)) { $ghostDll = Join-Path $script:SuiteRoot "GhostKey.dll" }
    if (-not (Test-Path $wraithTap)) { $wraithTap = Join-Path $script:SuiteRoot "WraithTap.exe" }
    
    if ((Test-Path $ghostDll) -and (Test-Path $wraithTap)) {
        Start-Process -WindowStyle Hidden -FilePath $wraithTap -ArgumentList $ghostDll
        Write-Console "GhostKey injected via WraithTap"
    } else {
        Write-Console "Missing binaries. Run Build Suite first."
        Write-Console "  GhostKey.dll: $(Test-Path $ghostDll)"
        Write-Console "  WraithTap.exe: $(Test-Path $wraithTap)"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnResidency.Add_Click({
    Write-Console "Loading GhostResidency module..."
    $modPath = Join-Path $script:SuiteRoot "GhostResidency.ps1"
    if (Test-Path $modPath) {
        . $modPath
        Write-Console "GhostResidency loaded - use Start-GhostResidency"
    } else {
        Write-Console "GhostResidency.ps1 not found"
    }
})

$elements.BtnHollow.Add_Click({
    Write-Console "Initializing Process Hollowing via GhostHollow..."
    $modPath = Join-Path $script:SuiteRoot "GhostHollow.ps1"
    if (Test-Path $modPath) {
        . $modPath
        Write-Console "GhostHollow module loaded"
    } else {
        Write-Console "GhostHollow.ps1 not found"
    }
})

$elements.BtnPolymorph.Add_Click({
    Write-Console "Starting Polymorph Build..."
    Set-Status "Building" "#ffcc00"
    $script = Join-Path $script:SuiteRoot "PolymorphBuild.ps1"
    if (Test-Path $script) {
        & $script
        Write-Console "Polymorph build completed"
    } else {
        Write-Console "PolymorphBuild.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

# Kernel Operations
$elements.BtnKernel.Add_Click({
    Write-Console "Deploying GhostKernel module..."
    Set-Status "Kernel Deploy" "#e94560"
    $modPath = Join-Path $script:SuiteRoot "Modules\GhostKernel.ps1"
    if (Test-Path $modPath) {
        . $modPath
        $tag = $elements.GhostTagInput.Text
        if (Get-Command -Name Start-GhostKernelSession -ErrorAction SilentlyContinue) {
            Start-GhostKernelSession -TargetDevice "/dev/sdb" -GhostTag $tag
            Write-Console "GhostKernel session initialized with tag: $tag"
        }
    } else {
        Write-Console "GhostKernel.ps1 not found in Modules"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnLinuxVM.Add_Click({
    Write-Console "Launching GhostLinux VM environment..."
    Set-Status "VM Boot" "#ffcc00"
    $linuxPdfExe = Join-Path $script:SuiteRoot "LinuxPDF.exe"
    $isoPath = Join-Path $script:SuiteRoot "ghost_boot.iso"
    
    if ((Test-Path $linuxPdfExe) -and (Test-Path $isoPath)) {
        Start-Process -FilePath $linuxPdfExe -ArgumentList "--boot=`"$isoPath`""
        Write-Console "LinuxPDF VM started with ghost_boot.iso"
    } else {
        Write-Console "Missing LinuxPDF.exe or ghost_boot.iso"
        Write-Console "Run CreateGhostISO.ps1 to create the ISO"
    }
    Set-Status "Ready" "#00ff00"
})

# Browser Operations
$elements.BtnGhostCore.Add_Click({
    Write-Console "Deploying GhostCore browser extension..."
    Set-Status "Browser Deploy" "#e94560"
    $modPath = Join-Path $script:SuiteRoot "Modules\GhostBrowser.ps1"
    if (Test-Path $modPath) {
        . $modPath
        $tag = $elements.GhostTagInput.Text
        if (Get-Command -Name Install-GhostBrowserExtension -ErrorAction SilentlyContinue) {
            Install-GhostBrowserExtension -ExtensionType "ghostcore" -GhostTag $tag
            Write-Console "GhostCore extension deployed"
        }
    } else {
        Write-Console "GhostBrowser.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnDiscord.Add_Click({
    Write-Console "Deploying Discord injection extension..."
    $modPath = Join-Path $script:SuiteRoot "Modules\GhostBrowser.ps1"
    if (Test-Path $modPath) {
        . $modPath
        $tag = $elements.GhostTagInput.Text
        if (Get-Command -Name Install-GhostBrowserExtension -ErrorAction SilentlyContinue) {
            Install-GhostBrowserExtension -ExtensionType "discord" -GhostTag $tag
            Write-Console "Discord extension deployed"
        }
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnChromeRDP.Add_Click({
    Write-Console "Installing Chrome Remote Desktop (stealth)..."
    Set-Status "RDP Install" "#ffcc00"
    $modPath = Join-Path $script:SuiteRoot "Modules\GhostDesktop.ps1"
    if (Test-Path $modPath) {
        . $modPath
        $tag = $elements.GhostTagInput.Text
        if (Get-Command -Name Install-GhostDesktop -ErrorAction SilentlyContinue) {
            $result = Install-GhostDesktop -GhostTag $tag -Silent
            if ($result) {
                Write-Console "Chrome RDP installed successfully"
            } else {
                Write-Console "Chrome RDP installation failed"
            }
        }
    } else {
        Write-Console "GhostDesktop.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

# Network/BLE Operations
$elements.BtnBLETrigger.Add_Click({
    Write-Console "Activating BLE Trigger..."
    Set-Status "BLE Active" "#00fff5"
    $script = Join-Path $script:SuiteRoot "BLETrigger.ps1"
    if (Test-Path $script) {
        & $script
        Write-Console "BLE Trigger activated"
    } else {
        Write-Console "BLETrigger.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnWormhole.Add_Click({
    Write-Console "Activating Wormhole listener..."
    Set-Status "Wormhole" "#e94560"
    $modPath = Join-Path $script:SuiteRoot "Modules\Invoke-GhostWorm.ps1"
    if (Test-Path $modPath) {
        . $modPath
        if (Get-Command -Name Start-WormholeListener -ErrorAction SilentlyContinue) {
            Start-WormholeListener
            Write-Console "Wormhole beacon active"
        }
    } else {
        Write-Console "Wormhole module not found"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnOBEX.Add_Click({
    Write-Console "Starting OBEX brute force (GhostBLEConnect_v2)..."
    $script = Join-Path $script:SuiteRoot "GhostBLEConnect_v2.ps1"
    if (Test-Path $script) {
        & $script
        Write-Console "OBEX brute force initiated"
    } else {
        Write-Console "GhostBLEConnect_v2.ps1 not found"
    }
})

# Utility Operations
$elements.BtnAnomalyHunter.Add_Click({
    Write-Console "Running Anomaly Hunter scan..."
    Set-Status "Scanning" "#ffcc00"
    $modPath = Join-Path $script:SuiteRoot "Modules\AnomalyHunter.ps1"
    if (Test-Path $modPath) {
        . $modPath
        if (Get-Command -Name Start-AnomalyHunt -ErrorAction SilentlyContinue) {
            Start-AnomalyHunt -Path "$env:SystemDrive\" -Log
            Write-Console "Anomaly scan complete"
        }
    } else {
        Write-Console "AnomalyHunter.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnExorcist.Add_Click({
    Write-Console "Launching ExorcistMode..."
    Set-Status "Exorcism" "#e94560"
    $modPath = Join-Path $script:SuiteRoot "Modules\ExorcistMode.ps1"
    if (Test-Path $modPath) {
        . $modPath
        if (Get-Command -Name Start-Exorcism -ErrorAction SilentlyContinue) {
            Start-Exorcism -Path $env:TEMP -Log
            Write-Console "Exorcism complete"
        }
    } else {
        Write-Console "ExorcistMode.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnSealEncrypt.Add_Click({
    Write-Console "Opening GhostSeal encryption..."
    $script = Join-Path $script:SuiteRoot "GhostSeal.ps1"
    if (Test-Path $script) {
        . $script
        Write-Console "GhostSeal loaded - use Invoke-GhostSeal"
    } else {
        Write-Console "GhostSeal.ps1 not found"
    }
})

$elements.BtnSealDecrypt.Add_Click({
    Write-Console "Opening GhostSeal decryption..."
    $script = Join-Path $script:SuiteRoot "GhostSealDecrypt.ps1"
    if (Test-Path $script) {
        . $script
        Write-Console "GhostSealDecrypt loaded"
    } else {
        Write-Console "GhostSealDecrypt.ps1 not found"
    }
})

$elements.BtnViewLogs.Add_Click({
    Write-Console "Reading Ghost operation logs..."
    $logPath = "$env:ProgramData\ghost_ops_log.txt"
    if (Test-Path $logPath) {
        $logs = Get-Content -Path $logPath -Tail 25
        $logs | ForEach-Object { Write-Console $_ }
    } else {
        Write-Console "No logs found at $logPath"
    }
})

$elements.BtnBuildSuite.Add_Click({
    Write-Console "Building GhostWhisper Suite..."
    Set-Status "Building" "#ffcc00"
    $script = Join-Path $script:SuiteRoot "BuildDeployWhisper.ps1"
    if (Test-Path $script) {
        & $script
        Write-Console "Suite build complete"
    } else {
        Write-Console "BuildDeployWhisper.ps1 not found"
    }
    Set-Status "Ready" "#00ff00"
})

# Cleanup Operations
$elements.BtnSilentBloom.Add_Click({
    Write-Console "Initiating SilentBloom full cleanup..."
    Set-Status "Cleanup" "#e94560"
    $confirm = [System.Windows.MessageBox]::Show(
        "This will remove all traces. Continue?",
        "SilentBloom Confirmation",
        "YesNo",
        "Warning"
    )
    if ($confirm -eq "Yes") {
        $script = Join-Path $script:SuiteRoot "SilentBloom.ps1"
        if (Test-Path $script) {
            & $script
            Write-Console "SilentBloom cleanup complete - all traces removed"
        } else {
            Write-Console "SilentBloom.ps1 not found"
        }
    } else {
        Write-Console "SilentBloom cancelled"
    }
    Set-Status "Ready" "#00ff00"
})

$elements.BtnClearLogs.Add_Click({
    Write-Console "Clearing Ghost operation logs..."
    $logPath = "$env:ProgramData\ghost_ops_log.txt"
    if (Test-Path $logPath) {
        Clear-Content -Path $logPath -Force
        Write-Console "Logs cleared"
    } else {
        Write-Console "No log file to clear"
    }
})

$elements.BtnAnoint.Add_Click({
    Write-Console "Executing Phase: Anoint..."
    $modPath = Join-Path $script:SuiteRoot "Modules\Phase_Anoint.ps1"
    if (Test-Path $modPath) {
        . $modPath
        Write-Console "Phase Anoint complete"
    }
})

$elements.BtnBind.Add_Click({
    Write-Console "Executing Phase: Bind..."
    $modPath = Join-Path $script:SuiteRoot "Modules\Phase_Bind.ps1"
    if (Test-Path $modPath) {
        . $modPath
        Write-Console "Phase Bind complete"
    }
})

$elements.BtnCleanse.Add_Click({
    Write-Console "Executing Phase: Cleanse..."
    $modPath = Join-Path $script:SuiteRoot "Modules\Phase_Cleanse.ps1"
    if (Test-Path $modPath) {
        . $modPath
        Write-Console "Phase Cleanse complete"
    }
})

# Initialize console
Write-Console "GhostWhisper Suite initialized"
Write-Console "Operator Console v2.0 - Raven Edition"
Write-Console "Suite Root: $script:SuiteRoot"
Write-Console "---"
Write-Console "Select a category tab, then choose an operation."
Write-Console "Use the command input for custom PowerShell commands."
Write-Console "---"

# Show window
$window.ShowDialog() | Out-Null
