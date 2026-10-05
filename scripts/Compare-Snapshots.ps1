# Compare-Snapshots.ps1
# Creates a human-readable report of meaningful changes between two triage runs

param(
    [Parameter(Mandatory=$true)]
    [string]$BaselinePath,

    [Parameter(Mandatory=$true)]
    [string]$AfterPath,

    [string]$ReportPath
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $outFile = Join-Path $AfterPath "SuspiciousChangesReport_$timestamp.txt"
} else {
    $outFile = $ReportPath
}

function Compare-Files {
    param($name)

    $baseFile  = Join-Path $BaselinePath $name
    $afterFile = Join-Path $AfterPath $name

    # Safely load baseline content
    if (Test-Path $baseFile) {
        $baseContent = Get-Content $baseFile
        if ($baseContent -eq $null) { $baseContent = @() }
    } else {
        $baseContent = @()
    }

    # Safely load after-run content
    if (Test-Path $afterFile) {
        $afterContent = Get-Content $afterFile
        if ($afterContent -eq $null) { $afterContent = @() }
    } else {
        $afterContent = @()
    }

    # Compare only new items
    $diff = Compare-Object $baseContent $afterContent |
            Where-Object { $_.SideIndicator -eq "=>" } |
            Select-Object -ExpandProperty InputObject

    return $diff
}

$sections = @{
    "New Processes"            = "processes.txt"
    "New Services"             = "services.txt"
    "New Startup (HKLM)"       = "startup_hklm.txt"
    "New Startup (HKCU)"       = "startup_hkcu.txt"
    "New Scheduled Tasks"      = "schtasks.txt"
    "New Network Connections"  = "netstat.txt"
    "Hosts File Changes"       = "hosts.txt"
    "New Installed Programs"   = "installed_programs.txt"
    "New Defender Detections"  = "defender_detections.txt"
}

"Suspicious Changes Report ($timestamp)" | Out-File $outFile
"======================================" | Out-File $outFile -Append

foreach ($section in $sections.Keys) {
    $file = $sections[$section]
    $changes = Compare-Files $file

    "`n$section`:" | Out-File $outFile -Append
    "------------------------" | Out-File $outFile -Append

    if ($changes.Count -eq 0) {
        "No changes detected." | Out-File $outFile -Append
    } else {
        $changes | Out-File $outFile -Append
    }
}

Write-Host "Done. Review $outFile"
