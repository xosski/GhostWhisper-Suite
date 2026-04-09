Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
EDRAudit.ps1
Blue-team EDR / AV / Defender posture audit module.

Purpose
- Detect common EDR / AV products by service, process, and uninstall inventory
- Summarize Microsoft Defender status when available
- Provide a compact posture summary for GhostShieldBootstrap logging and dashboard use

Design notes
- Defensive and read-only
- Best-effort enumeration; individual checks degrade gracefully
#>

$script:EDRAuditState = [ordered]@{
    Products = @(
        @{ Name = 'CrowdStrike Falcon'; ServicePatterns = @('CSFalcon*','CrowdStrike*'); ProcessPatterns = @('CSFalcon*','falcon*'); VendorPatterns = @('CrowdStrike') },
        @{ Name = 'Microsoft Defender'; ServicePatterns = @('WinDefend','Sense','WdNisSvc','SecurityHealthService'); ProcessPatterns = @('MsMpEng','SenseIR','NisSrv','SecurityHealthService'); VendorPatterns = @('Microsoft Defender','Microsoft') },
        @{ Name = 'SentinelOne'; ServicePatterns = @('Sentinel*','SentinelAgent*'); ProcessPatterns = @('SentinelAgent*','SentinelServiceHost*'); VendorPatterns = @('SentinelOne') },
        @{ Name = 'VMware Carbon Black'; ServicePatterns = @('CbDefense*','CarbonBlack*'); ProcessPatterns = @('Cb*','RepMgr*'); VendorPatterns = @('Carbon Black','VMware Carbon Black') },
        @{ Name = 'Sophos'; ServicePatterns = @('Sophos*','SntpService'); ProcessPatterns = @('Sophos*','SAVService*'); VendorPatterns = @('Sophos') },
        @{ Name = 'Cylance'; ServicePatterns = @('Cylance*'); ProcessPatterns = @('Cylance*'); VendorPatterns = @('Cylance') },
        @{ Name = 'ESET'; ServicePatterns = @('ekrn','ESET*'); ProcessPatterns = @('ekrn','egui','ecmd*'); VendorPatterns = @('ESET') },
        @{ Name = 'Kaspersky'; ServicePatterns = @('AVP*','Kaspersky*'); ProcessPatterns = @('avp*'); VendorPatterns = @('Kaspersky') },
        @{ Name = 'Symantec'; ServicePatterns = @('SepMasterService','Symantec*','SmcService'); ProcessPatterns = @('ccSvcHst','smc'); VendorPatterns = @('Symantec','Broadcom') },
        @{ Name = 'McAfee'; ServicePatterns = @('McAfee*','mf*'); ProcessPatterns = @('mcshield','masvc','mf*'); VendorPatterns = @('McAfee','Trellix') },
        @{ Name = 'Trellix / FireEye HX'; ServicePatterns = @('xagt','FireEye*'); ProcessPatterns = @('xagt','fef*'); VendorPatterns = @('Trellix','FireEye') },
        @{ Name = 'Palo Alto Cortex XDR'; ServicePatterns = @('cyserver','Traps*'); ProcessPatterns = @('cyserver','Traps*'); VendorPatterns = @('Palo Alto','Cortex') },
        @{ Name = 'Trend Micro'; ServicePatterns = @('ntrtscan','TmListen','Trend*'); ProcessPatterns = @('ntrtscan','tmccsf'); VendorPatterns = @('Trend Micro') },
        @{ Name = 'Bitdefender'; ServicePatterns = @('EPProtectedService','VSSERV'); ProcessPatterns = @('bdagent','vsserv'); VendorPatterns = @('Bitdefender') }
    )
}

function New-EDRAuditResult {
    param(
        [string]$Action,
        [string]$Status,
        [string]$Message,
        [hashtable]$Details = @{}
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        Action = $Action
        Status = $Status
        Message = $Message
        Details = $Details
    }
}

function Get-ServiceMatches {
    [CmdletBinding()]
    param(
        [string[]]$Patterns
    )

    $matches = @()
    foreach ($pattern in @($Patterns)) {
        try {
            $matches += @(Get-Service -Name $pattern -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType)
        } catch {}
    }
    return @($matches | Sort-Object Name -Unique)
}

function Get-ProcessMatches {
    [CmdletBinding()]
    param(
        [string[]]$Patterns
    )

    $matches = @()
    foreach ($pattern in @($Patterns)) {
        try {
            $matches += @(Get-Process -Name $pattern -ErrorAction SilentlyContinue | Select-Object Name, Id, Path, StartTime)
        } catch {}
    }
    return @($matches | Sort-Object Name, Id -Unique)
}

function Get-InstalledSecurityProducts {
    [CmdletBinding()]
    param()

    $results = New-Object System.Collections.Generic.List[object]

    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($root in $roots) {
        try {
            Get-ChildItem -Path $root -ErrorAction Stop | ForEach-Object {
                try {
                    $item = Get-ItemProperty -Path $_.PsPath -ErrorAction Stop
                    $name = [string]$item.DisplayName
                    if (-not $name) { return }
                    if ($name -match '(?i)defender|crowdstrike|sentinel|carbon black|sophos|cylance|eset|kaspersky|symantec|mcafee|trellix|fireeye|cortex|trend micro|bitdefender') {
                        $results.Add([pscustomobject]@{
                            DisplayName = $item.DisplayName
                            DisplayVersion = $item.DisplayVersion
                            Publisher = $item.Publisher
                            InstallLocation = $item.InstallLocation
                            UninstallString = $item.UninstallString
                        }) | Out-Null
                    }
                } catch {}
            }
        } catch {}
    }

    return @($results)
}

function Get-EDRPresence {
    [CmdletBinding()]
    param()

    $detected = New-Object System.Collections.Generic.List[object]
    $installed = Get-InstalledSecurityProducts

    foreach ($product in $script:EDRAuditState.Products) {
        $serviceHits = Get-ServiceMatches -Patterns $product.ServicePatterns
        $processHits = Get-ProcessMatches -Patterns $product.ProcessPatterns
        $inventoryHits = @($installed | Where-Object {
            $publisher = [string]$_.Publisher
            $display = [string]$_.DisplayName
            foreach ($vendor in $product.VendorPatterns) {
                if ($publisher -like "*$vendor*" -or $display -like "*$vendor*") { return $true }
            }
            return $false
        })

        if (@($serviceHits).Count -gt 0 -or @($processHits).Count -gt 0 -or @($inventoryHits).Count -gt 0) {
            $detected.Add([pscustomobject]@{
                Name = $product.Name
                Services = @($serviceHits)
                Processes = @($processHits)
                Inventory = @($inventoryHits)
                Active = [bool](@($serviceHits | Where-Object Status -eq 'Running').Count -gt 0 -or @($processHits).Count -gt 0)
            }) | Out-Null
        }
    }

    return @($detected)
}

function Get-AVStatus {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
            $products = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop |
                Select-Object displayName, instanceGuid, pathToSignedProductExe, pathToSignedReportingExe, productState, timestamp
            return @($products)
        }
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    return @([pscustomobject]@{ Error = 'SecurityCenter2 query unavailable' })
}

function Get-DefenderStatus {
    [CmdletBinding()]
    param()

    $result = [ordered]@{}

    try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $result.AMServiceEnabled = $mp.AMServiceEnabled
            $result.AntivirusEnabled = $mp.AntivirusEnabled
            $result.AntispywareEnabled = $mp.AntispywareEnabled
            $result.RealTimeProtectionEnabled = $mp.RealTimeProtectionEnabled
            $result.BehaviorMonitorEnabled = $mp.BehaviorMonitorEnabled
            $result.IoavProtectionEnabled = $mp.IoavProtectionEnabled
            $result.IsTamperProtected = $mp.IsTamperProtected
            $result.QuickScanAge = $mp.QuickScanAge
            $result.FullScanAge = $mp.FullScanAge
            $result.AntivirusSignatureVersion = $mp.AntivirusSignatureVersion
            $result.NISEnabled = $mp.NISEnabled
            $result.OnAccessProtectionEnabled = $mp.OnAccessProtectionEnabled
        } else {
            $result.Error = 'Get-MpComputerStatus unavailable'
        }
    } catch {
        $result.Error = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Get-EDRServiceHealth {
    [CmdletBinding()]
    param(
        [array]$DetectedProducts = $(Get-EDRPresence)
    )

    $health = New-Object System.Collections.Generic.List[object]

    foreach ($product in @($DetectedProducts)) {
        $runningServices = @($product.Services | Where-Object Status -eq 'Running').Count
        $serviceCount = @($product.Services).Count
        $processCount = @($product.Processes).Count
        $status = if ($product.Active) { 'Active' } elseif ($serviceCount -gt 0 -or $processCount -gt 0) { 'PresentButInactive' } else { 'Unknown' }

        $health.Add([pscustomobject]@{
            Name = $product.Name
            Status = $status
            RunningServices = $runningServices
            ServiceCount = $serviceCount
            ProcessCount = $processCount
        }) | Out-Null
    }

    return @($health)
}

function Get-EDRAuditSummary {
    [CmdletBinding()]
    param(
        [array]$DetectedProducts = $(Get-EDRPresence),
        $DefenderStatus = $(Get-DefenderStatus)
    )

    $health = Get-EDRServiceHealth -DetectedProducts $DetectedProducts
    $active = @($health | Where-Object Status -eq 'Active')

    $issues = New-Object System.Collections.Generic.List[object]

    if ($DefenderStatus.PSObject.Properties.Name -contains 'RealTimeProtectionEnabled') {
        if ($DefenderStatus.RealTimeProtectionEnabled -eq $false) {
            $issues.Add([pscustomobject]@{ Severity = 'HIGH'; Area = 'Defender'; Message = 'Real-time protection is disabled.' }) | Out-Null
        }
        if ($DefenderStatus.AMServiceEnabled -eq $false) {
            $issues.Add([pscustomobject]@{ Severity = 'HIGH'; Area = 'Defender'; Message = 'Defender antimalware service is disabled.' }) | Out-Null
        }
        if ($DefenderStatus.IsTamperProtected -eq $false) {
            $issues.Add([pscustomobject]@{ Severity = 'MEDIUM'; Area = 'Defender'; Message = 'Tamper protection is not enabled.' }) | Out-Null
        }
    }

    foreach ($entry in @($health)) {
        if ($entry.Status -eq 'PresentButInactive') {
            $issues.Add([pscustomobject]@{ Severity = 'MEDIUM'; Area = 'EDRHealth'; Message = "Security product present but not active: $($entry.Name)" }) | Out-Null
        }
    }

    [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        Hostname = $env:COMPUTERNAME
        DetectedCount = @($DetectedProducts).Count
        ActiveCount = @($active).Count
        ActiveProducts = @($active | Select-Object -ExpandProperty Name)
        Health = $health
        DefenderStatus = $DefenderStatus
        IssueCount = @($issues).Count
        Issues = @($issues)
    }
}

function Start-EDRAudit {
    [CmdletBinding()]
    param()

    $presence = Get-EDRPresence
    $av = Get-AVStatus
    $defender = Get-DefenderStatus
    $summary = Get-EDRAuditSummary -DetectedProducts $presence -DefenderStatus $defender

    [pscustomobject]@{
        Presence = $presence
        AVStatus = $av
        DefenderStatus = $defender
        Summary = $summary
    }
}

Export-ModuleMember -Function @(
    'Get-InstalledSecurityProducts',
    'Get-EDRPresence',
    'Get-AVStatus',
    'Get-DefenderStatus',
    'Get-EDRServiceHealth',
    'Get-EDRAuditSummary',
    'Start-EDRAudit'
)
