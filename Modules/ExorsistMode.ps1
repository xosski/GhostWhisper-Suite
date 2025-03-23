# ExorcistMode.ps1 - Windows Ghost Whisper Exorcism Protocol
# Modes: Anoint (Scan), Bind (Contain), Cleanse (Purge)
# Integrates with GhostWhisper logging and optional LinuxPDF sandboxing

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("anoint", "bind", "cleanse")]
    [string]$Mode,

    [switch]$UseVirtualization,
    [switch]$Log
)

function Suspend-Process {
    param([int]$Id)
    $sig = '[DllImport("ntdll.dll", SetLastError = true)] public static extern uint NtSuspendProcess(IntPtr ProcessHandle);'
    $ntapi = Add-Type -MemberDefinition $sig -Name "NTAPI" -Namespace "Win32" -PassThru
    $handle = (Get-Process -Id $Id).Handle
    $ntapi::NtSuspendProcess($handle)
}

function Invoke-Anoint {
    Write-Host "[🕊️] Anointing the host... (initial scan)"
    $targets = Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue |
               Where-Object { $_.Extension -match '\.(exe|dll|ps1|bat)' -and $_.Length -gt 100KB }

    $report = @()
    foreach ($file in $targets) {
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $entry = [PSCustomObject]@{
            Path     = $file.FullName
            SizeKB   = [math]::Round($file.Length / 1KB, 2)
            Modified = $file.LastWriteTime
            Hash     = $hash.Hash
        }
        $report += $entry
    }

    $report | Export-Csv -Path "$env:ProgramData\ghost_anoint_log.csv" -NoTypeInformation
    Write-Host "[+] Anoint report saved to ghost_anoint_log.csv"
}

function Invoke-Bind {
    Write-Host "[🔒] Binding unclean processes... (containment)"
    $suspectProcs = Get-Process | Where-Object {
        $_.Path -like "$env:TEMP*" -or $_.Path -like "*AppData*"
    }

    foreach ($proc in $suspectProcs) {
        try {
            Suspend-Process -Id $proc.Id
            Write-Host "[+] Suspended $($proc.Name) ($($proc.Id))"
        } catch {
            Write-Warning "[!] Failed to suspend $($proc.Name): $_"
        }
    }
}

function Invoke-Cleanse {
    Write-Host "[🔥] Cleansing the system... (secure deletion)"
    $filesToClean = Import-Csv "$env:ProgramData\ghost_anoint_log.csv" | Where-Object {
        $_.SizeKB -gt 100 -and $_.Path -like "$env:TEMP*"
    }

    foreach ($entry in $filesToClean) {
        try {
            cipher /w:$([System.IO.Path]::GetDirectoryName($entry.Path)) 2>$null
            Remove-Item -Path $entry.Path -Force -ErrorAction SilentlyContinue
            Write-Host "[-] Exorcised: $($entry.Path)"
        } catch {
            Write-Warning "[!] Failed to cleanse $($entry.Path): $_"
        }
    }
}

function Invoke-LinuxPDF-Virtualization {
    Write-Host "[*] Launching LinuxPDF sandbox (placeholder)"

    $LinuxPDF = "C:\ProgramData\LinuxPDF\ghost_boot.iso"
    if (-Not (Test-Path $LinuxPDF)) {
        Write-Warning "[!] LinuxPDF environment not found. Skipping virtualization."
        return
    }

    $VirtualCommand = @"
cd /mnt/target
case "$Mode" in
  Anoint) ls -la && sha256sum * ;;
  Bind) for pid in \$(pgrep suspicious); do kill -STOP \$pid; done ;;
  Cleanse) rm -rf /mnt/target/tmp/* ;;
esac
"@

    $ScriptPath = "$env:TEMP\ghost_virtual_script.sh"
    Set-Content -Path $ScriptPath -Value $VirtualCommand

    Write-Host "[+] Injecting GhostScript into LinuxPDF runtime..."
    Start-Process -FilePath "LinuxPDF.exe" -ArgumentList "--boot $LinuxPDF --exec $ScriptPath" -WindowStyle Hidden
    Add-Content -Path "$env:ProgramData\ghost_ops_log.txt" -Value "[`(Virtual:$Mode`)] Executed at $(Get-Date)"
}

function Update-GhostLog {
    $ghostLog = "$env:ProgramData\ghost_ops_log.txt"
    $entry = "[$(Get-Date -Format o)] Mode: $Mode invoked by $env:USERNAME"
    Add-Content -Path $ghostLog -Value $entry
}

# === Execution Flow ===

if ($UseVirtualization) {
    Invoke-LinuxPDF-Virtualization
} else {
    switch ($Mode) {
        "anoint"  { Invoke-Anoint }
        "bind"    { Invoke-Bind }
        "cleanse" { Invoke-Cleanse }
    }
}

Update-GhostLog
Write-Host "[✓] $Mode complete. Ghost log updated."
