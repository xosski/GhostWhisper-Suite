Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
Reporting.ps1
Blue-team reporting and case summary module.

Purpose
- Build readable incident-response outputs from GhostShield case artifacts
- Export structured summaries as JSON / CSV / HTML
- Summarize findings from collected snapshots, logs, containment, remediation, and evidence sealing

Design notes
- Defensive and auditable
- Consumes case folders produced by ArtifactCollector / EvidenceSeal
- Does not alter evidence content beyond report files written to a Reports folder
#>

$script:ReportingState = [ordered]@{
    OutputRoot = Join-Path $env:ProgramData 'GhostShield\Cases'
}

function New-ReportingResult {
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

function Resolve-ReportCaseDirectory {
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

    $resolved = Join-Path $script:ReportingState.OutputRoot $CaseId
    if (-not (Test-Path $resolved)) {
        throw "Case directory not found: $resolved"
    }
    return $resolved
}

function Get-CaseSubdirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [Parameter(Mandatory)] [string]$Name
    )

    $path = Join-Path $CaseDirectory $Name
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Read-JsonFileSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 20
    } catch {
        return [pscustomobject]@{ Error = $_.Exception.Message; Path = $Path }
    }
}

function Read-JsonLinesSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path
    )

    if (-not (Test-Path $Path)) { return @() }
    $items = @()
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            try {
                $items += ($line | ConvertFrom-Json -Depth 20)
            } catch {}
        }
    }
    return @($items)
}

function Get-CaseManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory
    )

    $manifestPath = Join-Path $CaseDirectory 'manifest.json'
    return Read-JsonFileSafe -Path $manifestPath
}

function Get-CaseChainOfCustody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory
    )

    $path = Join-Path $CaseDirectory 'chain_of_custody.json'
    return Read-JsonFileSafe -Path $path
}

function Get-CaseArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory
    )

    $artifactFiles = Get-ChildItem -Path $CaseDirectory -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -notmatch '\\Reports($|\\)' }

    return @($artifactFiles | Select-Object FullName, DirectoryName, Name, Length, LastWriteTime)
}

function Get-CaseFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory
    )

    $findings = New-Object System.Collections.Generic.List[object]

    $candidateFiles = @(
        (Join-Path $CaseDirectory 'Persistence\persistence_snapshot.json'),
        (Join-Path $CaseDirectory 'Browser\browser_snapshot.json'),
        (Join-Path $CaseDirectory 'Memory\memory_snapshot.json'),
        (Join-Path $CaseDirectory 'Network\network_snapshot.json')
    )

    foreach ($file in $candidateFiles) {
        $json = Read-JsonFileSafe -Path $file
        if (-not $json) { continue }

        if ($json.PSObject.Properties.Name -contains 'Findings') {
            foreach ($f in @($json.Findings)) {
                $findings.Add([pscustomobject]@{
                    SourceFile = $file
                    Type = $f.Type
                    Severity = $f.Severity
                    Name = $f.Name
                    Location = $f.Location
                    Description = $f.Description
                    Timestamp = $f.Timestamp
                }) | Out-Null
            }
        }

        if ($json.PSObject.Properties.Name -contains 'ListenerFindings') {
            foreach ($f in @($json.ListenerFindings)) {
                $findings.Add([pscustomobject]@{
                    SourceFile = $file
                    Type = $f.Type
                    Severity = $f.Severity
                    Name = $f.Name
                    Location = $f.Location
                    Description = $f.Description
                    Timestamp = $f.Timestamp
                }) | Out-Null
            }
        }

        if ($json.PSObject.Properties.Name -contains 'SuspiciousConnectionFindings') {
            foreach ($f in @($json.SuspiciousConnectionFindings)) {
                $findings.Add([pscustomobject]@{
                    SourceFile = $file
                    Type = $f.Type
                    Severity = $f.Severity
                    Name = $f.Name
                    Location = $f.Location
                    Description = $f.Description
                    Timestamp = $f.Timestamp
                }) | Out-Null
            }
        }
    }

    return @($findings)
}

function Get-FindingsSummary {
    [CmdletBinding()]
    param(
        [array]$Findings
    )

    $bySeverity = @{}
    $byType = @{}
    foreach ($f in @($Findings)) {
        $sev = if ($f.Severity) { [string]$f.Severity } else { 'UNKNOWN' }
        $typ = if ($f.Type) { [string]$f.Type } else { 'UNKNOWN' }
        if (-not $bySeverity.ContainsKey($sev)) { $bySeverity[$sev] = 0 }
        if (-not $byType.ContainsKey($typ)) { $byType[$typ] = 0 }
        $bySeverity[$sev]++
        $byType[$typ]++
    }

    [pscustomobject]@{
        Total = @($Findings).Count
        BySeverity = $bySeverity
        ByType = $byType
        HighSeverity = @(@($Findings) | Where-Object Severity -eq 'HIGH').Count
        MediumSeverity = @(@($Findings) | Where-Object Severity -eq 'MEDIUM').Count
        LowSeverity = @(@($Findings) | Where-Object Severity -eq 'LOW').Count
    }
}

function Get-CaseTimeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [string]$JsonLogPath
    )

    $timeline = New-Object System.Collections.Generic.List[object]

    if ($JsonLogPath -and (Test-Path $JsonLogPath)) {
        foreach ($evt in Read-JsonLinesSafe -Path $JsonLogPath) {
            $timeline.Add([pscustomobject]@{
                Timestamp = $evt.ts
                Source = 'GhostLogger'
                Component = $evt.component
                Level = $evt.level
                Message = $evt.message
            }) | Out-Null
        }
    }

    $manifest = Get-CaseManifest -CaseDirectory $CaseDirectory
    if ($manifest -and $manifest.GeneratedAt) {
        $timeline.Add([pscustomobject]@{
            Timestamp = $manifest.GeneratedAt
            Source = 'EvidenceManifest'
            Component = 'ArtifactCollector'
            Level = 'INFO'
            Message = 'Manifest generated'
        }) | Out-Null
    }

    $coc = Get-CaseChainOfCustody -CaseDirectory $CaseDirectory
    if ($coc -and $coc.Actions) {
        foreach ($action in @($coc.Actions)) {
            $timeline.Add([pscustomobject]@{
                Timestamp = $action.Timestamp
                Source = 'ChainOfCustody'
                Component = 'EvidenceSeal'
                Level = 'INFO'
                Message = $action.Action
            }) | Out-Null
        }
    }

    return @($timeline | Sort-Object Timestamp)
}

function New-CaseSummary {
    [CmdletBinding()]
    param(
        [string]$CaseId,
        [string]$CaseDirectory,
        [string]$JsonLogPath
    )

    $resolved = Resolve-ReportCaseDirectory -CaseId $CaseId -CaseDirectory $CaseDirectory
    $resolvedCaseId = if ($CaseId) { $CaseId } else { Split-Path $resolved -Leaf }
    $manifest = Get-CaseManifest -CaseDirectory $resolved
    $artifacts = Get-CaseArtifacts -CaseDirectory $resolved
    $findings = Get-CaseFindings -CaseDirectory $resolved
    $summary = Get-FindingsSummary -Findings $findings
    $timeline = Get-CaseTimeline -CaseDirectory $resolved -JsonLogPath $JsonLogPath
    $chain = Get-CaseChainOfCustody -CaseDirectory $resolved

    [pscustomobject]@{
        CaseId = $resolvedCaseId
        CaseDirectory = $resolved
        Hostname = if ($manifest -and $manifest.Hostname) { $manifest.Hostname } else { $env:COMPUTERNAME }
        Operator = if ($manifest -and $manifest.Operator) { $manifest.Operator } else { $env:USERNAME }
        GeneratedAt = (Get-Date).ToString('o')
        ArtifactCount = @($artifacts).Count
        Findings = $findings
        FindingsSummary = $summary
        Timeline = $timeline
        Manifest = $manifest
        ChainOfCustody = $chain
    }
}

function Export-FindingsJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [Parameter(Mandatory)] $ReportObject
    )

    $reportsDir = Get-CaseSubdirectory -CaseDirectory $CaseDirectory -Name 'Reports'
    $path = Join-Path $reportsDir 'findings_report.json'
    $ReportObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding UTF8 -Force
    return New-ReportingResult -Action 'ExportFindingsJson' -Status 'Success' -Target $path -Message 'JSON report exported' -Details @{ Path = $path }
}

function Export-FindingsCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$CaseDirectory,
        [Parameter(Mandatory)] [array]$Findings
    )

    $reportsDir = Get-CaseSubdirectory -CaseDirectory $CaseDirectory -Name 'Reports'
    $path = Join-Path $reportsDir 'findings_report.csv'
    $Findings | Select-Object Timestamp, SourceFile, Type, Severity, Name, Location, Description |
        Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
    return New-ReportingResult -Action 'ExportFindingsCsv' -Status 'Success' -Target $path -Message 'CSV report exported' -Details @{ Path = $path }
}

function Convert-SummaryToHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Summary
    )

    $severityRows = ''
    foreach ($key in ($Summary.FindingsSummary.BySeverity.Keys | Sort-Object)) {
        $severityRows += "<tr><td>$key</td><td>$($Summary.FindingsSummary.BySeverity[$key])</td></tr>"
    }

    $typeRows = ''
    foreach ($key in ($Summary.FindingsSummary.ByType.Keys | Sort-Object)) {
        $typeRows += "<tr><td>$key</td><td>$($Summary.FindingsSummary.ByType[$key])</td></tr>"
    }

    $findingRows = ''
    foreach ($f in @($Summary.Findings)) {
        $findingRows += "<tr><td>$($f.Timestamp)</td><td>$($f.Type)</td><td>$($f.Severity)</td><td>$($f.Name)</td><td>$($f.Location)</td><td>$($f.Description)</td></tr>"
    }

    $timelineRows = ''
    foreach ($t in @($Summary.Timeline)) {
        $timelineRows += "<tr><td>$($t.Timestamp)</td><td>$($t.Source)</td><td>$($t.Component)</td><td>$($t.Level)</td><td>$($t.Message)</td></tr>"
    }

    @"
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<title>GhostShield Case Report - $($Summary.CaseId)</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #222; }
h1, h2 { color: #0b4f6c; }
table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }
th, td { border: 1px solid #ccc; padding: 8px; vertical-align: top; text-align: left; }
th { background: #f3f6f9; }
.meta { margin-bottom: 24px; }
.code { font-family: Consolas, monospace; }
</style>
</head>
<body>
<h1>GhostShield Incident Report</h1>
<div class="meta">
<p><strong>Case ID:</strong> $($Summary.CaseId)</p>
<p><strong>Hostname:</strong> $($Summary.Hostname)</p>
<p><strong>Operator:</strong> $($Summary.Operator)</p>
<p><strong>Generated:</strong> $($Summary.GeneratedAt)</p>
<p><strong>Artifact Count:</strong> $($Summary.ArtifactCount)</p>
<p><strong>Total Findings:</strong> $($Summary.FindingsSummary.Total)</p>
</div>

<h2>Findings by Severity</h2>
<table>
<tr><th>Severity</th><th>Count</th></tr>
$severityRows
</table>

<h2>Findings by Type</h2>
<table>
<tr><th>Type</th><th>Count</th></tr>
$typeRows
</table>

<h2>Findings Detail</h2>
<table>
<tr><th>Timestamp</th><th>Type</th><th>Severity</th><th>Name</th><th>Location</th><th>Description</th></tr>
$findingRows
</table>

<h2>Timeline</h2>
<table>
<tr><th>Timestamp</th><th>Source</th><th>Component</th><th>Level</th><th>Message</th></tr>
$timelineRows
</table>
</body>
</html>
"@
}

function New-IncidentReport {
    [CmdletBinding()]
    param(
        [string]$CaseId,
        [string]$CaseDirectory,
        [string]$JsonLogPath
    )

    try {
        $summary = New-CaseSummary -CaseId $CaseId -CaseDirectory $CaseDirectory -JsonLogPath $JsonLogPath
        $reportsDir = Get-CaseSubdirectory -CaseDirectory $summary.CaseDirectory -Name 'Reports'

        $jsonResult = Export-FindingsJson -CaseDirectory $summary.CaseDirectory -ReportObject $summary
        $csvResult = Export-FindingsCsv -CaseDirectory $summary.CaseDirectory -Findings @($summary.Findings)

        $html = Convert-SummaryToHtml -Summary $summary
        $htmlPath = Join-Path $reportsDir 'incident_report.html'
        $html | Set-Content -LiteralPath $htmlPath -Encoding UTF8 -Force
        $htmlResult = New-ReportingResult -Action 'ExportIncidentHtml' -Status 'Success' -Target $htmlPath -Message 'HTML report exported' -Details @{ Path = $htmlPath }

        return [pscustomobject]@{
            Summary = $summary
            JsonReport = $jsonResult
            CsvReport = $csvResult
            HtmlReport = $htmlResult
        }
    } catch {
        return [pscustomobject]@{
            Error = $_.Exception.Message
            CaseId = $CaseId
            CaseDirectory = $CaseDirectory
        }
    }
}

Export-ModuleMember -Function @(
    'Resolve-ReportCaseDirectory',
    'Get-CaseManifest',
    'Get-CaseChainOfCustody',
    'Get-CaseArtifacts',
    'Get-CaseFindings',
    'Get-FindingsSummary',
    'Get-CaseTimeline',
    'New-CaseSummary',
    'Export-FindingsJson',
    'Export-FindingsCsv',
    'New-IncidentReport'
)
