# CreateGhostISO.ps1
# PowerShell script to create a bootable ISO for GhostWhisper

param (
    [string]$IsoName = "ghost_boot.iso",
    [string]$WorkingDir = "$PSScriptRoot\GhostISO",
    [string]$OscdimgPath = "$env:ProgramFiles(x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    [string]$MkisofsPath = "$PSScriptRoot\Tools\mkisofs.exe"
)

function Test-Command {
    param ([string]$Command)
    try {
        $null = & $Command /?
        return $true
    }
    catch {
        return $false
    }
}

function Create-ISO-Oscdimg {
    param (
        [string]$SourceDir,
        [string]$IsoPath,
        [string]$OscdimgExe
    )
    Write-Host "Creating ISO using oscdimg.exe..."
    $bootSector = "$SourceDir\boot\isolinux\isolinux.bin"
    $command = "`"$OscdimgExe`" -b$bootSector -h -lGHOST_BOOT -m -o `"$SourceDir`" `"$IsoPath`""
    Write-Host $command
    Invoke-Expression $command
}

function Create-ISO-Mkisofs {
    param (
        [string]$SourceDir,
        [string]$IsoPath,
        [string]$MkisofsExe
    )
    Write-Host "Creating ISO using mkisofs.exe..."
    $bootSector = "$SourceDir\boot\isolinux\isolinux.bin"
    $command = "`"$MkisofsExe`" -o `"$IsoPath`" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V GHOST_BOOT `"$SourceDir`""
    Write-Host $command
    Invoke-Expression $command
}

# Main Execution
if (-Not (Test-Path $WorkingDir)) {
    Write-Host "Error: Working directory '$WorkingDir' does not exist."
    exit 1
}

$IsoPath = Join-Path -Path $PSScriptRoot -ChildPath $IsoName

if (Test-Path $OscdimgPath) {
    Create-ISO-Oscdimg -SourceDir $WorkingDir -IsoPath $IsoPath -OscdimgExe $OscdimgPath
}
elseif (Test-Path $MkisofsPath) {
    Create-ISO-Mkisofs -SourceDir $WorkingDir -IsoPath $IsoPath -MkisofsExe $MkisofsPath
}
else {
    Write-Host "Error: Neither oscdimg.exe nor mkisofs.exe was found. Please ensure one of these tools is available."
    exit 1
}

Write-Host "ISO creation complete: $IsoPath"
