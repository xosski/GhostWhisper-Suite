Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
EvidenceSeal.ps1
Blue-team evidence integrity and archive module.

Purpose
- Hash collected evidence artifacts
- Build or enrich a manifest with integrity metadata
- Package a case directory into an archive
- Emit a simple chain-of-custody record

Design notes
- Defensive and auditable
- Does not alter evidence contents except to add sidecar metadata files
- Works with ArtifactCollector case folders and manifest.json
#>

$script:EvidenceSealState = [ordered]@{
    OutputRoot = Join-Path $env:ProgramData 'GhostShield\Cases'
    SealSuffix = '_sealed'
}

function New-EvidenceSealResult {
    param(
        [string]$Action,
        [string]$Status,
        [string]$Target,
        [string]$Message,
        [hashtable]$Details = @{}
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Action = $Action
        Status = $Status
        Target = $Target
        Message = $Message
        Details = $Details
    }
}

function Resolve-CaseDirectory {
    [CmdletBinding()]
    param(
        [string]$CaseId,
        [string]$CaseDirectory
    )

    if ($CaseDirectory) {
        if (Test-Path $CaseDirectory) { return $CaseDirectory }
        throw "Case directory not found: $CaseDirectory"
    }

    if (-not $CaseId) {
        throw 'CaseId or CaseDirectory is required.'
    }

    $resolved = Join-Path $script:EvidenceSealState.OutputRoot $CaseId
    if (-not (Test-Path $resolved)) {
        throw "Case directory not found: $resolved"
    }
    return $resolved
}

function Get-EvidenceHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [switch]$Recurse
    )

    $items = @()
    if (Test-Path $Path -PathType Leaf) {
        $items = @(Get-Item -LiteralPath $Path -Force)
    } elseif (Test-Path $Path -PathType Container) {
        $items = @(Get-ChildItem -LiteralPath $Path -File -Force -Recurse:$Recurse)
    } else {
        throw "Path not found: $Path"
    }

    $hashes = foreach ($item in $items) {
        try {
            [pscustomobject]@{
                Path = $item.FullName
                RelativePath = $null
                Length = $item.Length
                LastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
                SHA256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                SHA1 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA1 -ErrorAction Stop).Hash
                MD5 = (Get-FileHash -LiteralPath $item.FullName -Algorithm MD5 -ErrorAction Stop).Hash
            }
        } catch {
            [pscustomobject]@{
                Path = $item.FullName
                RelativePath = $null
                Length = $item.Length
                LastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
                SHA256 = $null
                SHA1 = $null
                MD5 = $null
                Error = $_.Exception.Message
            }
        }
    }

    return @($hashes)
}

function New-EvidenceManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [string]$CaseId,
        [string]$Operator = $env:USERNAME,
        [switch]$IncludeExistingManifest
    )

    $manifestPath = Join-Path $CaseDirectory 'manifest.json'
    $hashes = Get-EvidenceHashes -Path $CaseDirectory -Recurse

    foreach ($h in $hashes) {
        $h.RelativePath = $h.Path.Substring($CaseDirectory.Length).TrimStart('\')
    }

    $existingManifest = $null
    if ($IncludeExistingManifest -and (Test-Path $manifestPath)) {
        try {
            $existingManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        } catch {}
    }

    $manifest = [pscustomobject]@{
        CaseId = $(if ($CaseId) { $CaseId } else { Split-Path $CaseDirectory -Leaf })
        Hostname = $env:COMPUTERNAME
        Operator = $Operator
        GeneratedAt = (Get-Date).ToString('o')
        RootPath = $CaseDirectory
        ExistingManifest = $existingManifest
        FileCount = @($hashes).Count
        Files = $hashes
    }

    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8 -Force

    return New-EvidenceSealResult -Action 'NewManifest' -Status 'Success' -Target $manifestPath -Message 'Evidence manifest generated' -Details @{
        ManifestPath = $manifestPath
        FileCount = @($hashes).Count
    }
}

function Export-ChainOfCustody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [string]$CaseId,
        [string]$Operator = $env:USERNAME,
        [string]$Notes = ''
    )

    $path = Join-Path $CaseDirectory 'chain_of_custody.json'
    $record = [pscustomobject]@{
        CaseId = $(if ($CaseId) { $CaseId } else { Split-Path $CaseDirectory -Leaf })
        Hostname = $env:COMPUTERNAME
        Operator = $Operator
        CreatedAt = (Get-Date).ToString('o')
        Notes = $Notes
        Actions = @(
            [pscustomobject]@{
                Timestamp = (Get-Date).ToString('o')
                Action = 'Evidence collection package sealed'
                Actor = $Operator
                Host = $env:COMPUTERNAME
            }
        )
    }

    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8 -Force

    return New-EvidenceSealResult -Action 'ChainOfCustody' -Status 'Success' -Target $path -Message 'Chain of custody file created' -Details @{
        Path = $path
    }
}

function Compress-EvidenceBundle {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [string]$ArchivePath
    )

    if (-not $ArchivePath) {
        $caseName = Split-Path $CaseDirectory -Leaf
        $ArchivePath = Join-Path (Split-Path $CaseDirectory -Parent) ($caseName + $script:EvidenceSealState.SealSuffix + '.zip')
    }

    try {
        if (Test-Path $ArchivePath) {
            Remove-Item -LiteralPath $ArchivePath -Force -ErrorAction Stop
        }

        if ($PSCmdlet.ShouldProcess($CaseDirectory, 'Compress evidence bundle')) {
            Compress-Archive -Path (Join-Path $CaseDirectory '*') -DestinationPath $ArchivePath -CompressionLevel Optimal -Force -ErrorAction Stop
            return New-EvidenceSealResult -Action 'CompressBundle' -Status 'Success' -Target $ArchivePath -Message 'Evidence bundle compressed' -Details @{
                ArchivePath = $ArchivePath
            }
        }
    } catch {
        return New-EvidenceSealResult -Action 'CompressBundle' -Status 'Error' -Target $ArchivePath -Message 'Failed to compress evidence bundle' -Details @{ Error = $_.Exception.Message }
    }
}

function Protect-EvidenceBundle {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$CaseId,
        [string]$CaseDirectory,
        [string]$Operator = $env:USERNAME,
        [string]$Notes = ''
    )

    try {
        $resolvedCaseDir = Resolve-CaseDirectory -CaseId $CaseId -CaseDirectory $CaseDirectory
        $resolvedCaseId = if ($CaseId) { $CaseId } else { Split-Path $resolvedCaseDir -Leaf }

        $manifestResult = New-EvidenceManifest -CaseDirectory $resolvedCaseDir -CaseId $resolvedCaseId -Operator $Operator -IncludeExistingManifest
        $chainResult = Export-ChainOfCustody -CaseDirectory $resolvedCaseDir -CaseId $resolvedCaseId -Operator $Operator -Notes $Notes
        $zipResult = Compress-EvidenceBundle -CaseDirectory $resolvedCaseDir -WhatIf:$WhatIfPreference

        $archiveHashes = $null
        if ($zipResult.Status -eq 'Success' -and $zipResult.Details.ArchivePath -and (Test-Path $zipResult.Details.ArchivePath)) {
            $archiveHashes = Get-EvidenceHashes -Path $zipResult.Details.ArchivePath
            $hashPath = Join-Path $resolvedCaseDir 'archive_hashes.json'
            $archiveHashes | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $hashPath -Encoding UTF8 -Force
        }

        return [pscustomobject]@{
            CaseId = $resolvedCaseId
            CaseDirectory = $resolvedCaseDir
            Manifest = $manifestResult
            ChainOfCustody = $chainResult
            Archive = $zipResult
            ArchiveHashes = $archiveHashes
        }
    } catch {
        return [pscustomobject]@{
            CaseId = $CaseId
            CaseDirectory = $CaseDirectory
            Error = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function @(
    'Resolve-CaseDirectory',
    'Get-EvidenceHashes',
    'New-EvidenceManifest',
    'Export-ChainOfCustody',
    'Compress-EvidenceBundle',
    'Protect-EvidenceBundle'
)
