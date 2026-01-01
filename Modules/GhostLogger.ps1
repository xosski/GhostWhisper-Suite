# Modules/GhostLogger.ps1 v1.6.0
# Advanced ghost activity logger with encryption, rotation, and stealth capabilities

$script:Version = "1.6.0"
$script:DefaultLogPath = "$env:ProgramData\ghost_ops_log.txt"
$script:EncryptedLogPath = "$env:ProgramData\.glog.enc"
$script:MaxLogSizeMB = 5
$script:MaxLogFiles = 5
$script:EncryptionKey = "RavenLives2017"
$script:StealthMode = $false

function Initialize-GhostLogger {
    param(
        [string]$LogPath = $script:DefaultLogPath,
        [switch]$Stealth,
        [switch]$Encrypted,
        [int]$MaxSizeMB = 5,
        [int]$MaxFiles = 5
    )
    
    $script:DefaultLogPath = $LogPath
    $script:StealthMode = $Stealth
    $script:MaxLogSizeMB = $MaxSizeMB
    $script:MaxLogFiles = $MaxFiles
    
    if ($Encrypted) {
        $script:EncryptedLogPath = $LogPath -replace '\.txt$', '.enc'
    }
    
    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
    }
    
    Write-GhostLog "GhostLogger v$script:Version initialized" -Component "Logger"
}

function Write-GhostLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [string]$LogFile = $script:DefaultLogPath,
        
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "SUCCESS", "CRITICAL")]
        [string]$Level = "INFO",
        
        [string]$Component = "Ghost",
        
        [switch]$Encrypted,
        
        [switch]$NoTimestamp,
        
        [hashtable]$Metadata
    )
    
    $timestamp = if ($NoTimestamp) { "" } else { Get-Date -Format o }
    
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Component = $Component
        Message = $Message
        Host = $env:COMPUTERNAME
        User = $env:USERNAME
        PID = $PID
    }
    
    if ($Metadata) {
        $logEntry.Metadata = $Metadata
    }
    
    if ($script:StealthMode) {
        $formattedEntry = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($logEntry | ConvertTo-Json -Compress)))
    } else {
        $formattedEntry = "[$timestamp][$Level][$Component] $Message"
    }
    
    try {
        Invoke-LogRotation -LogFile $LogFile
        
        if ($Encrypted) {
            $encryptedEntry = Protect-LogEntry -Entry $formattedEntry
            Add-Content -Path $script:EncryptedLogPath -Value $encryptedEntry -ErrorAction SilentlyContinue
        } else {
            Add-Content -Path $LogFile -Value $formattedEntry -ErrorAction SilentlyContinue
        }
        
        if ($script:StealthMode) {
            $file = Get-Item $LogFile -ErrorAction SilentlyContinue
            if ($file) {
                $file.Attributes = [System.IO.FileAttributes]::Hidden
            }
        }
        
    } catch {
        # Silent fail in stealth mode
    }
}

function Read-GhostLog {
    param(
        [string]$LogFile = $script:DefaultLogPath,
        
        [int]$Tail = 25,
        
        [switch]$Encrypted,
        
        [string]$FilterLevel,
        
        [string]$FilterComponent,
        
        [datetime]$Since,
        
        [switch]$AsObject
    )
    
    $targetFile = if ($Encrypted) { $script:EncryptedLogPath } else { $LogFile }
    
    if (-not (Test-Path $targetFile)) {
        Write-Warning "[GhostLogger] Log file not found: $targetFile"
        return @()
    }
    
    try {
        $lines = Get-Content -Path $targetFile -Tail $Tail
        
        if ($Encrypted) {
            $lines = $lines | ForEach-Object { Unprotect-LogEntry -Entry $_ }
        }
        
        if ($script:StealthMode) {
            $lines = $lines | ForEach-Object {
                try {
                    $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_))
                    $decoded | ConvertFrom-Json
                } catch { $_ }
            }
        }
        
        if ($FilterLevel) {
            $lines = $lines | Where-Object { $_ -match "\[$FilterLevel\]" }
        }
        
        if ($FilterComponent) {
            $lines = $lines | Where-Object { $_ -match "\[$FilterComponent\]" }
        }
        
        if ($Since) {
            $lines = $lines | Where-Object {
                if ($_ -match '^\[([^\]]+)\]') {
                    try {
                        $logTime = [datetime]::Parse($Matches[1])
                        return $logTime -ge $Since
                    } catch { return $true }
                }
                return $true
            }
        }
        
        if ($AsObject) {
            return $lines | ForEach-Object {
                if ($_ -match '^\[([^\]]+)\]\[([^\]]+)\]\[([^\]]+)\]\s*(.+)$') {
                    [PSCustomObject]@{
                        Timestamp = $Matches[1]
                        Level = $Matches[2]
                        Component = $Matches[3]
                        Message = $Matches[4]
                    }
                } else { $_ }
            }
        } else {
            return $lines
        }
        
    } catch {
        Write-Warning "[GhostLogger] Failed to read log: $($_.Exception.Message)"
        return @()
    }
}

function Clear-GhostLog {
    param(
        [string]$LogFile = $script:DefaultLogPath,
        
        [switch]$SecureWipe,
        
        [switch]$All
    )
    
    try {
        if ($All) {
            $logDir = Split-Path $LogFile
            $logPattern = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
            $allLogs = Get-ChildItem -Path $logDir -Filter "$logPattern*" -ErrorAction SilentlyContinue
            
            foreach ($log in $allLogs) {
                if ($SecureWipe) {
                    Invoke-SecureWipe -FilePath $log.FullName
                } else {
                    Remove-Item -Path $log.FullName -Force -ErrorAction SilentlyContinue
                }
            }
            
            Write-Host "[GhostLogger] Cleared all logs: $($allLogs.Count) files"
        } else {
            if (Test-Path $LogFile) {
                if ($SecureWipe) {
                    Invoke-SecureWipe -FilePath $LogFile
                } else {
                    Clear-Content -Path $LogFile -ErrorAction SilentlyContinue
                }
                Write-Host "[GhostLogger] Cleared log: $LogFile"
            }
        }
        
    } catch {
        Write-Warning "[GhostLogger] Failed to clear log: $($_.Exception.Message)"
    }
}

function Invoke-LogRotation {
    param([string]$LogFile)
    
    if (-not (Test-Path $LogFile)) { return }
    
    $logSize = (Get-Item $LogFile).Length / 1MB
    
    if ($logSize -ge $script:MaxLogSizeMB) {
        $logDir = Split-Path $LogFile
        $logName = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
        $logExt = [System.IO.Path]::GetExtension($LogFile)
        
        for ($i = $script:MaxLogFiles; $i -ge 1; $i--) {
            $oldLog = Join-Path $logDir "$logName.$i$logExt"
            $newLog = Join-Path $logDir "$logName.$($i + 1)$logExt"
            
            if ($i -eq $script:MaxLogFiles -and (Test-Path $oldLog)) {
                Remove-Item $oldLog -Force -ErrorAction SilentlyContinue
            } elseif (Test-Path $oldLog) {
                Move-Item $oldLog $newLog -Force -ErrorAction SilentlyContinue
            }
        }
        
        $rotatedLog = Join-Path $logDir "$logName.1$logExt"
        Move-Item $LogFile $rotatedLog -Force -ErrorAction SilentlyContinue
        
        Write-GhostLog "Log rotated: $LogFile" -Component "Logger" -Level "DEBUG"
    }
}

function Protect-LogEntry {
    param([string]$Entry)
    
    try {
        $key = [Text.Encoding]::UTF8.GetBytes($script:EncryptionKey.PadRight(32).Substring(0, 32))
        $iv = @(1..16 | ForEach-Object { [byte](Get-Random -Minimum 0 -Maximum 256) })
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $encryptor = $aes.CreateEncryptor()
        $plainBytes = [Text.Encoding]::UTF8.GetBytes($Entry)
        $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
        
        $combined = $iv + $encryptedBytes
        return [Convert]::ToBase64String($combined)
        
    } catch {
        return $Entry
    }
}

function Unprotect-LogEntry {
    param([string]$Entry)
    
    try {
        $combined = [Convert]::FromBase64String($Entry)
        $iv = $combined[0..15]
        $encryptedBytes = $combined[16..($combined.Length - 1)]
        
        $key = [Text.Encoding]::UTF8.GetBytes($script:EncryptionKey.PadRight(32).Substring(0, 32))
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $decryptor = $aes.CreateDecryptor()
        $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
        
        return [Text.Encoding]::UTF8.GetString($decryptedBytes)
        
    } catch {
        return $Entry
    }
}

function Invoke-SecureWipe {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return }
    
    try {
        $fileSize = (Get-Item $FilePath).Length
        $randomBytes = New-Object byte[] $fileSize
        
        for ($pass = 0; $pass -lt 3; $pass++) {
            [Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
            [System.IO.File]::WriteAllBytes($FilePath, $randomBytes)
        }
        
        Remove-Item $FilePath -Force
        
    } catch {
        Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
    }
}

function Export-GhostLog {
    param(
        [string]$LogFile = $script:DefaultLogPath,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [ValidateSet("JSON", "CSV", "TXT")]
        [string]$Format = "JSON",
        
        [switch]$Encrypted,
        
        [int]$LastN = 1000
    )
    
    $logs = Read-GhostLog -LogFile $LogFile -Tail $LastN -AsObject
    
    switch ($Format) {
        "JSON" {
            $logs | ConvertTo-Json -Depth 5 | Set-Content $OutputPath
        }
        "CSV" {
            $logs | Export-Csv -Path $OutputPath -NoTypeInformation
        }
        "TXT" {
            $logs | Out-File $OutputPath
        }
    }
    
    if ($Encrypted) {
        $content = Get-Content $OutputPath -Raw
        $encContent = Protect-LogEntry -Entry $content
        Set-Content $OutputPath -Value $encContent
    }
    
    Write-Host "[GhostLogger] Exported to: $OutputPath"
}

function Get-GhostLogStats {
    param([string]$LogFile = $script:DefaultLogPath)
    
    if (-not (Test-Path $LogFile)) {
        return @{ Exists = $false }
    }
    
    $content = Get-Content $LogFile
    $stats = @{
        Exists = $true
        TotalLines = $content.Count
        SizeKB = [math]::Round((Get-Item $LogFile).Length / 1KB, 2)
        LastModified = (Get-Item $LogFile).LastWriteTime
        Levels = @{
            INFO = ($content | Where-Object { $_ -match '\[INFO\]' }).Count
            WARN = ($content | Where-Object { $_ -match '\[WARN\]' }).Count
            ERROR = ($content | Where-Object { $_ -match '\[ERROR\]' }).Count
            DEBUG = ($content | Where-Object { $_ -match '\[DEBUG\]' }).Count
            SUCCESS = ($content | Where-Object { $_ -match '\[SUCCESS\]' }).Count
            CRITICAL = ($content | Where-Object { $_ -match '\[CRITICAL\]' }).Count
        }
    }
    
    return $stats
}

function Watch-GhostLog {
    param(
        [string]$LogFile = $script:DefaultLogPath,
        [string]$FilterLevel
    )
    
    Write-Host "[GhostLogger] Watching: $LogFile (Ctrl+C to stop)" -ForegroundColor Cyan
    
    $lastPosition = 0
    if (Test-Path $LogFile) {
        $lastPosition = (Get-Item $LogFile).Length
    }
    
    while ($true) {
        if (Test-Path $LogFile) {
            $currentSize = (Get-Item $LogFile).Length
            
            if ($currentSize -gt $lastPosition) {
                $stream = [System.IO.File]::Open($LogFile, 'Open', 'Read', 'ReadWrite')
                $stream.Seek($lastPosition, 'Begin') | Out-Null
                $reader = New-Object System.IO.StreamReader($stream)
                
                while ($line = $reader.ReadLine()) {
                    if (-not $FilterLevel -or $line -match "\[$FilterLevel\]") {
                        $color = if ($line -match '\[ERROR\]|\[CRITICAL\]') { "Red" }
                                elseif ($line -match '\[WARN\]') { "Yellow" }
                                elseif ($line -match '\[SUCCESS\]') { "Green" }
                                else { "White" }
                        Write-Host $line -ForegroundColor $color
                    }
                }
                
                $lastPosition = $stream.Position
                $reader.Close()
                $stream.Close()
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
}

Export-ModuleMember -Function Initialize-GhostLogger, Write-GhostLog, Read-GhostLog, Clear-GhostLog
Export-ModuleMember -Function Export-GhostLog, Get-GhostLogStats, Watch-GhostLog
Export-ModuleMember -Function Protect-LogEntry, Unprotect-LogEntry
