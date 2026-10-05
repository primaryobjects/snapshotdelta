# Capture-SnapshotDetail.ps1
# Detailed post-execution triage script for Windows VMs including full paths and descriptions of processes and files
# Collects targeted evidence after running suspicious software

# Create output folder with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = "C:\SnapshotDelta_$timestamp"
New-Item -ItemType Directory -Path $outDir | Out-Null

Write-Host "Saving results to $outDir"

# --- Process and services ---
Get-Process | Select-Object Id,ProcessName,CPU,Path |
    Sort-Object CPU -Descending |
    Out-File "$outDir\processes.txt"

Get-Service | Where-Object {$_.Status -eq 'Running'} |
    Select-Object Name,DisplayName |
    Out-File "$outDir\services.txt"

# --- Startup and scheduled tasks ---
Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" |
    Out-File "$outDir\startup_hklm.txt"

Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
    Out-File "$outDir\startup_hkcu.txt"

schtasks /Query /FO LIST /V |
    Select-String "TaskName|Next Run Time|Status" |
    Out-File "$outDir\schtasks.txt"

# --- Network activity ---
netstat -ano | Select-String "ESTABLISHED" |
    Out-File "$outDir\netstat.txt"

# --- Hosts file ---
Get-Content C:\Windows\System32\drivers\etc\hosts |
    Out-File "$outDir\hosts.txt"

# --- Defender status and detections ---
Get-MpComputerStatus | Out-File "$outDir\defender_status.txt"
Get-MpThreatDetection | Out-File "$outDir\defender_detections.txt"

# --- Installed programs (short list) ---
Get-WmiObject Win32_Product | Select-Object Name,Version |
    Out-File "$outDir\installed_programs.txt"

Write-Host "Post-run checks complete. Review files in $outDir"
