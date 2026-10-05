# Capture-Snapshot.ps1 (Normalized Version)
# Produces stable, diff-friendly triage output for hardened VMs

param(
    [string]$OutputDirectory
)

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outDir = "C:\SnapshotDelta_$timestamp"
    $suffix = 1
    while (Test-Path $outDir) {
        $outDir = "C:\SnapshotDelta_${timestamp}_$suffix"
        $suffix++
    }
} else {
    $outDir = $OutputDirectory
}

if (Test-Path -LiteralPath $outDir) {
    throw "Snapshot directory already exists: $outDir"
}

New-Item -ItemType Directory -Path $outDir -ErrorAction Stop | Out-Null

Write-Host "Saving normalized triage output to $outDir"

# -----------------------------
# Normalized Processes
# -----------------------------
Get-Process |
    Select-Object -ExpandProperty ProcessName |
    Sort-Object |
    Out-File "$outDir\processes.txt"

# -----------------------------
# Normalized Services
# -----------------------------
Get-Service |
    Select-Object -ExpandProperty Name |
    Sort-Object |
    Out-File "$outDir\services.txt"

# -----------------------------
# Normalized Startup (HKLM)
# -----------------------------
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" |
    Get-Member -MemberType NoteProperty |
    Select-Object -ExpandProperty Name |
    Sort-Object |
    Out-File "$outDir\startup_hklm.txt"

# -----------------------------
# Normalized Startup (HKCU)
# -----------------------------
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
    Get-Member -MemberType NoteProperty |
    Select-Object -ExpandProperty Name |
    Sort-Object |
    Out-File "$outDir\startup_hkcu.txt"

# -----------------------------
# Normalized Scheduled Tasks
# -----------------------------
schtasks /query /fo LIST |
    Select-String "TaskName:" |
    ForEach-Object { ($_ -split ":")[1].Trim() } |
    Sort-Object |
    Out-File "$outDir\schtasks.txt"

# -----------------------------
# Normalized Network Connections
# -----------------------------
netstat -n |
    Select-String "TCP" |
    ForEach-Object {
        # Extract remote IP only (ignore ephemeral ports)
        $parts = ($_ -split "\s+")
        if ($parts.Length -ge 4) {
            ($parts[3] -split ":")[0]
        }
    } |
    Sort-Object |
    Out-File "$outDir\netstat.txt"

# -----------------------------
# Hosts File (Normalized)
# -----------------------------
Get-Content "C:\Windows\System32\drivers\etc\hosts" |
    Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" } |
    Sort-Object |
    Out-File "$outDir\hosts.txt"

# -----------------------------
# Installed Programs (Normalized)
# -----------------------------
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne "" } |
    Select-Object -ExpandProperty DisplayName |
    Sort-Object |
    Out-File "$outDir\installed_programs.txt"

# -----------------------------
# Defender Status (Normalized)
# -----------------------------
Get-MpComputerStatus |
    Select-Object AMServiceEnabled, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled |
    Format-List |
    Out-File "$outDir\defender_status.txt"

# -----------------------------
# Defender Detections (Normalized)
# -----------------------------
Get-MpThreatDetection |
    Select-Object ThreatName, ActionSuccess, InitialDetectionTime |
    Sort-Object ThreatName |
    Out-File "$outDir\defender_detections.txt"

Write-Host "Done."
