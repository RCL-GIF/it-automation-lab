<#
.SYNOPSIS
    Performs a read-only Windows Update assessment and writes structured reports.

.DESCRIPTION
    Sanitized lab artifact demonstrating an automation-first patch assessment workflow.
    The script checks Windows Update service state, pending reboot indicators, and
    applicable updates, then exports JSON and CSV reports for downstream review.

    IMPORTANT:
    - This script does NOT install updates.
    - This script does NOT restart services.
    - This script does NOT reboot the endpoint.
    - No credentials, employer data, or proprietary infrastructure details are included.

.PARAMETER OutputDirectory
    Directory where JSON and CSV reports will be written.
    Defaults to ".\reports".

.PARAMETER IncludeDrivers
    Include applicable driver updates in addition to software updates.

.EXAMPLE
    .\Invoke-PatchAssessment.ps1

.EXAMPLE
    .\Invoke-PatchAssessment.ps1 -OutputDirectory C:\Temp\PatchReports -IncludeDrivers

.NOTES
    AssessmentCode is written into the JSON report:
    0  No pending updates or reboot detected.
    10 Pending updates and/or reboot detected.

    This lab version does not terminate the PowerShell host with a process exit code.
    An orchestration platform can map AssessmentCode to its own success/warning logic.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputDirectory = ".\reports",

    [Parameter()]
    [switch]$IncludeDrivers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-PendingReboot {
    [CmdletBinding()]
    param()

    $rebootRegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )

    foreach ($path in $rebootRegistryPaths) {
        if (Test-Path -Path $path) {
            return $true
        }
    }

    try {
        $sessionManager = Get-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
            -Name "PendingFileRenameOperations" `
            -ErrorAction Stop

        if ($null -ne $sessionManager.PendingFileRenameOperations) {
            return $true
        }
    }
    catch {
        # Missing PendingFileRenameOperations is normal when no reboot is pending.
    }

    return $false
}

function Get-PendingWindowsUpdates {
    [CmdletBinding()]
    param(
        [switch]$IncludeDrivers
    )

    $updateSession = New-Object -ComObject "Microsoft.Update.Session"
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    $searchCriteria = if ($IncludeDrivers) {
        "IsInstalled=0 and IsHidden=0"
    }
    else {
        "IsInstalled=0 and IsHidden=0 and Type='Software'"
    }

    $searchResult = $updateSearcher.Search($searchCriteria)
    $updates = @()

    for ($index = 0; $index -lt $searchResult.Updates.Count; $index++) {
        $update = $searchResult.Updates.Item($index)

        $kbIds = @($update.KBArticleIDs)
        $categories = @(
            for ($categoryIndex = 0; $categoryIndex -lt $update.Categories.Count; $categoryIndex++) {
                $update.Categories.Item($categoryIndex).Name
            }
        )

        $updates += [PSCustomObject]@{
            Title          = $update.Title
            KB             = ($kbIds -join ",")
            Severity       = if ([string]::IsNullOrWhiteSpace($update.MsrcSeverity)) { "Unspecified" } else { $update.MsrcSeverity }
            IsDownloaded   = [bool]$update.IsDownloaded
            RebootRequired = [bool]$update.RebootRequired
            Categories     = ($categories -join "; ")
        }
    }

    return $updates
}

try {
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $wuService = Get-CimInstance -ClassName Win32_Service -Filter "Name='wuauserv'"
    $pendingReboot = Test-PendingReboot
    $pendingUpdates = @(Get-PendingWindowsUpdates -IncludeDrivers:$IncludeDrivers)

    $status = if (($pendingUpdates.Count -eq 0) -and (-not $pendingReboot)) {
        "Ready"
    }
    else {
        "AttentionRequired"
    }

    $severitySummary = $pendingUpdates |
        Group-Object -Property Severity |
        Sort-Object -Property Name |
        ForEach-Object {
            [PSCustomObject]@{
                Severity = $_.Name
                Count    = $_.Count
            }
        }

    $assessmentCode = if ($status -eq "Ready") { 0 } else { 10 }

    $report = [ordered]@{
        SchemaVersion      = "1.0"
        AssessmentStatus   = $status
        AssessmentCode     = $assessmentCode
        AssessedAtUtc      = (Get-Date).ToUniversalTime().ToString("o")
        ComputerName       = $env:COMPUTERNAME
        OperatingSystem    = [ordered]@{
            Caption        = $os.Caption
            Version        = $os.Version
            BuildNumber    = $os.BuildNumber
            LastBootTime   = $os.LastBootUpTime
        }
        WindowsUpdate      = [ordered]@{
            ServiceState   = $wuService.State
            StartMode      = $wuService.StartMode
            PendingReboot  = $pendingReboot
            IncludeDrivers = [bool]$IncludeDrivers
            PendingCount   = $pendingUpdates.Count
        }
        SeveritySummary    = @($severitySummary)
        Updates            = @($pendingUpdates)
    }

    $jsonPath = Join-Path -Path $OutputDirectory -ChildPath "patch-assessment-$timestamp.json"
    $csvPath = Join-Path -Path $OutputDirectory -ChildPath "pending-updates-$timestamp.csv"

    $report |
        ConvertTo-Json -Depth 8 |
        Set-Content -Path $jsonPath -Encoding UTF8

    $pendingUpdates |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host "Windows Patch Assessment"
    Write-Host "------------------------"
    Write-Host "Computer:        $($env:COMPUTERNAME)"
    Write-Host "Status:          $status"
    Write-Host "Pending updates: $($pendingUpdates.Count)"
    Write-Host "Pending reboot:  $pendingReboot"
    Write-Host "JSON report:     $jsonPath"
    Write-Host "CSV report:      $csvPath"
    Write-Host ""

    [PSCustomObject]@{
        ComputerName     = $env:COMPUTERNAME
        AssessmentStatus = $status
        AssessmentCode   = $assessmentCode
        PendingUpdates   = $pendingUpdates.Count
        PendingReboot    = $pendingReboot
        JsonReport       = $jsonPath
        CsvReport        = $csvPath
    }
}
catch {
    Write-Error "Patch assessment failed: $($_.Exception.Message)"
}
