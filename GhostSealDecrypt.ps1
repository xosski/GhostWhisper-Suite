# GhostSealDecrypt.ps1
param (
    [string]$SealedFilePath,
    [string]$OriginalFileName,
    [datetime]$OriginalAccessTime,
    [string]$OutputPath = "$env:TEMP\unsealed_output"
)

function Derive-Key {
    param ([string]$filename, [datetime]$accessTime)
    $timeBytes = [BitConverter]::GetBytes($accessTime.Ticks)
    $nameBytes = [System.Text.Encoding]::UTF8.GetBytes($filename)
    $xorKey = New-Object byte[] ($nameBytes.Length)
    for ($i = 0; $i -lt $nameBytes.Length; $i++) {
        $xorKey[$i] = $nameBytes[$i] -bxor $timeBytes[$i % $timeBytes.Length]
    }
    return $xorKey
}

function Decrypt-File {
    param ([string]$filePath, [byte[]]$key, [string]$outputPath)
    $data = [System.IO.File]::ReadAllBytes($filePath)
    $dec = New-Object byte[] $data.Length
    for ($i = 0; $i -lt $data.Length; $i++) {
        $dec[$i] = $data[$i] -bxor $key[$i % $key.Length]
    }
    [System.IO.File]::WriteAllBytes($outputPath, $dec)
}

$key = Derive-Key -filename $OriginalFileName -accessTime $OriginalAccessTime
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$outFile = Join-Path $OutputPath $OriginalFileName
Decrypt-File -filePath $SealedFilePath -key $key -outputPath $outFile