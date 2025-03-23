function Start-VirtualCleansing {
    param([string]$Path, [switch]$Log)

    Write-Host "[*] Emulating Linux PDF-based environment..."
    Start-Sleep -Seconds 2
    Write-Host "[*] Mounting virtual scan layer..."

    $virtualFiles = Start-AnointPhase -Path $Path -Log:$Log
    Start-BindPhase -FilesToCheck $virtualFiles
    Start-CleansePhase -FilesToWipe $virtualFiles -Log:$Log

    Write-Host "[✓] Virtual cleansing complete."
}
