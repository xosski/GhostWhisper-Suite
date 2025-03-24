# BuildAll.ps1
Write-Host "[*] Building .NET app..."
dotnet publish .\LinuxPDF\LinuxPDF.csproj -c Release -r win-x64 --self-contained true -o .\OperatorsKit

Write-Host "[*] Generating ghost_boot.iso..."
.\Tools\CreateGhostISO.ps1 -IsoName ghost_boot.iso -WorkingDir .\Tools\CreateGhostISO\boot

Write-Host "[*] Copy QEMU binaries..."
Copy-Item .\QEMU\* .\OperatorsKit\ -Force

Write-Host "[*] Move ISO to operators kit..."
Copy-Item .\Tools\CreateGhostISO\ghost_boot.iso .\OperatorsKit\ -Force

Write-Host "[✅] All done. OperatorsKit folder is ready!"
