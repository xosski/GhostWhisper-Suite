# Modules/GhostRoot.ps1
# Low-Level Disk Sector Analysis & Structure Recovery (GhostRoot)

function Get-RawSectors {
    param(
        [Parameter(Mandatory)] [string]$Device,
        [int]$Count = 10,
        [int]$SectorSize = 512
    )

    Write-Host "[*] Reading $Count sector(s) from $Device"
    $fs = [System.IO.File]::Open($Device, 'Open', 'Read', 'ReadWrite')
    $buffers = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $buffer = New-Object byte[] $SectorSize
        $fs.Read($buffer, 0, $SectorSize) | Out-Null
        $buffers += , $buffer
    }
    $fs.Close()
    return $buffers
}

function Analyze-SectorData {
    param(
        [byte[]]$Buffer,
        [switch]$Log
    )

    $hex = ($Buffer | ForEach-Object { $_.ToString("X2") }) -join ' '
    Write-Host "[+] Sector Preview: $($hex.Substring(0, 64))..."
    if ($Log) {
        Write-GhostLog -Message "GhostRoot sector scan: $($hex.Substring(0, 64))..."
    }
}

function Start-VirtualDiskAnalysis {
    param(
        [string]$Device,
        [switch]$Log
    )

    $shimPath = "$env:TEMP\ghost_disk_virtual.sh"
    Set-Content -Path $shimPath -Value @"
dd if=$Device bs=512 count=10 | hexdump -C
"@
    Write-Host "[*] Launching LinuxPDF with disk analysis shim..."
    Start-Process -FilePath "LinuxPDF.exe" -ArgumentList "--exec $shimPath" -WindowStyle Hidden

    if ($Log) {
        Write-GhostLog -Message "[GhostRoot] Virtual analysis launched for $Device"
    }
}

function Start-GhostRootScan {
    param(
        [string]$Device = "\\.\PhysicalDrive0",
        [switch]$UseVirtualization,
        [switch]$Log
    )

    Write-Host "[👁️] GhostRoot scan on $Device"
    if ($UseVirtualization) {
        Start-VirtualDiskAnalysis -Device $Device -Log:$Log
        return
    }

    try {
        $sectors = Get-RawSectors -Device $Device -Count 10
        foreach ($sector in $sectors) {
            Analyze-SectorData -Buffer $sector -Log:$Log
        }
        Write-Host "[✓] GhostRoot scan complete."
    }
    catch {
        Write-Warning "[!] GhostRoot failed: $_"
        if ($Log) { Write-GhostLog -Message "[GhostRoot] Error: $_" }
    }
}
