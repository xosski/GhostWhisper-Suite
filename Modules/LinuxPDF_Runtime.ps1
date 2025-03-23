# LinuxPDF_Runtime.ps1
# Virtual Cleansing Runtime Module for ExorcistMode
# Executes Anoint, Bind, and Cleanse in emulated LinuxPDF context

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("anoint", "bind", "cleanse", "exorcism")]
    [string]$Mode,

    [string]$Path = "$env:TEMP",

    [switch]$Offline = $false,
    [switch]$Log = $false
)

Import-Module "$PSScriptRoot\Phase_Anoint.ps1" -Force
Import-Module "$PSScriptRoot\Phase_Bind.ps1" -Force
Import-Module "$PSScriptRoot\Phase_Cleanse.ps1" -Force

function Start-LinuxPDFRuntime {
    param (
        [string]$Mode,
        [string]$Path,
        [switch]$Offline,
        [switch]$Log
    )

    Write-Host "[🌀] Starting LinuxPDF Virtual Runtime in mode: $Mode"
    Write-Host "[📂] Target path: $Path"
    if ($Offline) { Write-Host "[🧪] Running in OFFLINE sandbox mode" }

    $targets = @()

    if ($Mode -in @("anoint", "exorcism")) {
        $targets = Start-AnointPhase -Path $Path -Log:$Log
    }

    if ($Mode -in @("bind", "exorcism")) {
        if (-not $targets) {
            $targets = Start-AnointPhase -Path $Path -Log:$Log
        }
        Start-BindPhase -FilesToCheck $targets
    }

    if ($Mode -in @("cleanse", "exorcism")) {
        if (-not $targets) {
            $targets = Start-AnointPhase -Path $Path -Log:$Log
        }

        if ($Offline) {
            Write-Host "[🧼] Offline mode enabled - simulating cleanse"
            foreach ($file in $targets) {
                Write-Host "[SIM] Would cleanse: $($file.FullName)"
            }
        }
        else {
            Start-CleansePhase -FilesToWipe $targets -Log:$Log
        }
    }

    Write-Host "[✓] LinuxPDF Virtual Runtime ($Mode) complete."
}
