# GhostLogger.ps1 — Lightweight user activity logger with encrypted output
param(
    [string]$logPath = "$env:TEMP\ghost_usage.log",
    [string]$ghostCfgPath = "C:\ProgramData\.ghost.cfg"
)

function Get-GhostTag {
    if (Test-Path $ghostCfgPath) {
        try {
            $cfg = Get-Content $ghostCfgPath | ConvertFrom-Json
            return $cfg.ghostTag
        }
        catch {}
    }
    return "GENERIC"
}

function Derive-Key($tag) {
    $base = "RavenLives"
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes($base)
    $bytes = [Text.Encoding]::UTF8.GetBytes($tag)
    return ($hmac.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ''
}

function Encrypt-Log($key, $inPath, $outPath) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = [Convert]::FromBase64String($key.Substring(0, 44).PadRight(44, 'A'))
    $aes.IV = @(1..16)
    $enc = $aes.CreateEncryptor()

    $data = [IO.File]::ReadAllBytes($inPath)
    $out = New-Object IO.MemoryStream
    $cs = New-Object Security.Cryptography.CryptoStream($out, $enc, [Security.Cryptography.CryptoStreamMode]::Write)
    $cs.Write($data, 0, $data.Length)
    $cs.Close()
    [IO.File]::WriteAllBytes($outPath, $out.ToArray())
}

# Main
Start-Transcript -Path $logPath -Append | Out-Null

# Example logging
Write-Output "[$(Get-Date -Format o)] Clicked: C:\Users\Public\Secrets.docx"
Write-Output "[$(Get-Date -Format o)] Accessed: C:\ProgramData\Ledger.xlsx"
Stop-Transcript | Out-Null

$tag = Get-GhostTag
$key = Derive-Key $tag
$encLog = "$logPath.enc"
Encrypt-Log $key $logPath $encLog
Remove-Item $logPath -Force
Write-Host "[✓] Ghost log encrypted using rotating key based on tag: $tag"
