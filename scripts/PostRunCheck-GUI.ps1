param()

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "PostRunCheck GUI can only run on Windows."
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$snapshotScript = Join-Path $scriptDirectory "PostRunCheck.ps1"
$compareScript = Join-Path $scriptDirectory "Compare-Triage.ps1"
$snapshotRoot = "C:\"

foreach ($scriptPath in @($snapshotScript, $compareScript)) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Required script not found: $scriptPath"
    }
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory=$true)][string]$Value)

    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Get-SnapshotDirectories {
    return @(Get-ChildItem -LiteralPath $snapshotRoot -Directory -Filter "PostRunChecks_*" -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "PostRunCheck - Sandbox Triage"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(900, 690)
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)

$snapshotButton = New-Object System.Windows.Forms.Button
$snapshotButton.Text = "Take Snapshot"
$snapshotButton.Location = New-Object System.Drawing.Point(16, 16)
$snapshotButton.Size = New-Object System.Drawing.Size(145, 34)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh Snapshots"
$refreshButton.Location = New-Object System.Drawing.Point(171, 16)
$refreshButton.Size = New-Object System.Drawing.Size(145, 34)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Run as Administrator to save snapshots to C:\ and collect all indicators."
$statusLabel.Location = New-Object System.Drawing.Point(330, 24)
$statusLabel.Size = New-Object System.Drawing.Size(535, 24)
$statusLabel.Anchor = "Top,Left,Right"

$baselineLabel = New-Object System.Windows.Forms.Label
$baselineLabel.Text = "Baseline snapshot:"
$baselineLabel.Location = New-Object System.Drawing.Point(18, 70)
$baselineLabel.Size = New-Object System.Drawing.Size(145, 22)

$baselineCombo = New-Object System.Windows.Forms.ComboBox
$baselineCombo.DropDownStyle = "DropDownList"
$baselineCombo.Location = New-Object System.Drawing.Point(166, 66)
$baselineCombo.Size = New-Object System.Drawing.Size(690, 24)
$baselineCombo.Anchor = "Top,Left,Right"

$afterLabel = New-Object System.Windows.Forms.Label
$afterLabel.Text = "After snapshot:"
$afterLabel.Location = New-Object System.Drawing.Point(18, 106)
$afterLabel.Size = New-Object System.Drawing.Size(145, 22)

$afterCombo = New-Object System.Windows.Forms.ComboBox
$afterCombo.DropDownStyle = "DropDownList"
$afterCombo.Location = New-Object System.Drawing.Point(166, 102)
$afterCombo.Size = New-Object System.Drawing.Size(690, 24)
$afterCombo.Anchor = "Top,Left,Right"

$compareButton = New-Object System.Windows.Forms.Button
$compareButton.Text = "Compare Snapshots"
$compareButton.Location = New-Object System.Drawing.Point(18, 142)
$compareButton.Size = New-Object System.Drawing.Size(160, 34)

$openFolderButton = New-Object System.Windows.Forms.Button
$openFolderButton.Text = "Open Selected Snapshot"
$openFolderButton.Location = New-Object System.Drawing.Point(190, 142)
$openFolderButton.Size = New-Object System.Drawing.Size(180, 34)

$resultsTabs = New-Object System.Windows.Forms.TabControl
$resultsTabs.Location = New-Object System.Drawing.Point(18, 190)
$resultsTabs.Size = New-Object System.Drawing.Size(847, 445)
$resultsTabs.Anchor = "Top,Bottom,Left,Right"
$resultsTabs.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$resultsTabs.DrawMode = "OwnerDrawFixed"
$resultsTabs.ItemSize = New-Object System.Drawing.Size(145, 28)
$resultsTabs.add_DrawItem({
    param($sender, $eventArgs)

    $page = $sender.TabPages[$eventArgs.Index]
    $eventArgs.DrawBackground()
    $isChanged = $page.Tag -is [bool] -and $page.Tag
    $isUnchanged = $page.Tag -is [bool] -and -not $page.Tag
    if ($isChanged) {
        $symbol = [string][char]0x2716
        $color = [System.Drawing.Color]::Firebrick
    } elseif ($isUnchanged) {
        $symbol = [string][char]0x2713
        $color = [System.Drawing.Color]::ForestGreen
    } elseif ($page.Tag -eq "Overview") {
        $symbol = [string][char]0x25A6
        $color = [System.Drawing.SystemColors]::ControlText
    } else {
        $symbol = [string][char]0x2630
        $color = [System.Drawing.SystemColors]::ControlText
    }

    $iconFont = New-Object System.Drawing.Font("Segoe UI Symbol", 9, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush($color)
    try {
        $iconBounds = New-Object System.Drawing.RectangleF(
            ($eventArgs.Bounds.X + 5),
            ($eventArgs.Bounds.Y + 5),
            18,
            18
        )
        $textBounds = New-Object System.Drawing.RectangleF(
            ($eventArgs.Bounds.X + 24),
            ($eventArgs.Bounds.Y + 4),
            ($eventArgs.Bounds.Width - 26),
            20
        )
        $eventArgs.Graphics.DrawString($symbol, $iconFont, $brush, $iconBounds)
        $eventArgs.Graphics.DrawString($page.Text, $sender.Font, [System.Drawing.SystemBrushes]::ControlText, $textBounds)
    } finally {
        $brush.Dispose()
        $iconFont.Dispose()
    }
})

$fullReportPage = New-Object System.Windows.Forms.TabPage
$fullReportPage.Text = "Full Report"
$fullReportBox = New-Object System.Windows.Forms.TextBox
$fullReportBox.Multiline = $true
$fullReportBox.ReadOnly = $true
$fullReportBox.WordWrap = $false
$fullReportBox.ScrollBars = "Both"
$fullReportBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$fullReportBox.Dock = "Fill"
$fullReportBox.Text = "Take a snapshot after starting the app, then take another after running the software you want to inspect.`r`nSelect the two snapshots above and click Compare Snapshots."
$fullReportPage.Controls.Add($fullReportBox)
[void]$resultsTabs.TabPages.Add($fullReportPage)

$form.Controls.AddRange(@(
    $snapshotButton, $refreshButton, $statusLabel, $baselineLabel,
    $baselineCombo, $afterLabel, $afterCombo, $compareButton,
    $openFolderButton, $resultsTabs
))

function Set-FullReportView {
    param([string]$Text)

    $resultsTabs.TabPages.Clear()
    [void]$resultsTabs.TabPages.Add($fullReportPage)
    $resultsTabs.SelectedTab = $fullReportPage
    $fullReportBox.Text = $Text
}

function Show-ComparisonResults {
    param([string]$ReportText)

    $sectionNames = @(
        "New Processes",
        "New Services",
        "New Startup (HKLM)",
        "New Startup (HKCU)",
        "New Scheduled Tasks",
        "New Network Connections",
        "Hosts File Changes",
        "New Installed Programs",
        "New Defender Detections"
    )
    $sections = [ordered]@{}
    $shortNames = @{
        "New Processes" = "Processes"
        "New Services" = "Services"
        "New Startup (HKLM)" = "Startup HKLM"
        "New Startup (HKCU)" = "Startup HKCU"
        "New Scheduled Tasks" = "Scheduled Tasks"
        "New Network Connections" = "Network Connections"
        "Hosts File Changes" = "Hosts File"
        "New Installed Programs" = "Installed Programs"
        "New Defender Detections" = "Defender Detections"
    }
    foreach ($sectionName in $sectionNames) {
        $sections[$sectionName] = New-Object System.Collections.Generic.List[string]
    }

    $currentSection = $null
    foreach ($line in ($ReportText -split "\r?\n")) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine.EndsWith(":")) {
            $candidate = $trimmedLine.Substring(0, $trimmedLine.Length - 1)
            if ($sections.Contains($candidate)) {
                $currentSection = $candidate
                continue
            }
        }
        if (-not $currentSection -or [string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine -match '^-{3,}$') {
            continue
        }
        [void]$sections[$currentSection].Add($trimmedLine)
    }

    $resultsTabs.TabPages.Clear()
    $overviewPage = New-Object System.Windows.Forms.TabPage
    $overviewPage.Text = "Overview"
    $overviewPage.Tag = "Overview"
    $overviewPage.BackColor = [System.Drawing.Color]::White
    $overviewPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $overviewPanel.Dock = "Fill"
    $overviewPanel.AutoScroll = $true
    $overviewPanel.WrapContents = $true
    $overviewPanel.Padding = New-Object System.Windows.Forms.Padding(12)
    [void]$resultsTabs.TabPages.Add($overviewPage)
    $overviewPage.Controls.Add($overviewPanel)

    $changedSections = 0
    foreach ($sectionName in $sectionNames) {
        $entries = @($sections[$sectionName] | Where-Object { $_ -ne "No changes detected." })
        $hasChanges = $entries.Count -gt 0
        if ($hasChanges) {
            $changedSections++
        }

        $page = New-Object System.Windows.Forms.TabPage
        $page.Text = $shortNames[$sectionName]
        $page.Tag = [bool]$hasChanges
        $page.BackColor = [System.Drawing.Color]::White

        $detailsBox = New-Object System.Windows.Forms.TextBox
        $detailsBox.Multiline = $true
        $detailsBox.ReadOnly = $true
        $detailsBox.WordWrap = $true
        $detailsBox.ScrollBars = "Vertical"
        $detailsBox.Font = New-Object System.Drawing.Font("Consolas", 10)
        $detailsBox.Dock = "Fill"
        if ($hasChanges) {
            $detailsBox.Text = $entries -join [Environment]::NewLine
        } else {
            $detailsBox.Text = "No changes detected in this section."
        }

        $header = New-Object System.Windows.Forms.Panel
        $header.Height = 105
        $header.Dock = "Top"

        $iconLabel = New-Object System.Windows.Forms.Label
        $iconLabel.Text = if ($hasChanges) { [string][char]0x2716 } else { [string][char]0x2713 }
        $iconLabel.ForeColor = if ($hasChanges) { [System.Drawing.Color]::Firebrick } else { [System.Drawing.Color]::ForestGreen }
        $iconLabel.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 40, [System.Drawing.FontStyle]::Bold)
        $iconLabel.Location = New-Object System.Drawing.Point(16, 8)
        $iconLabel.Size = New-Object System.Drawing.Size(68, 78)
        $iconLabel.TextAlign = "MiddleCenter"

        $headingLabel = New-Object System.Windows.Forms.Label
        $headingLabel.Text = $sectionName
        $headingLabel.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
        $headingLabel.Location = New-Object System.Drawing.Point(98, 17)
        $headingLabel.Size = New-Object System.Drawing.Size(690, 30)
        $headingLabel.Anchor = "Top,Left,Right"

        $summaryLabel = New-Object System.Windows.Forms.Label
        $summaryLabel.Text = if ($hasChanges) {
            "$($entries.Count) new or changed item(s) - review the details below."
        } else {
            "No changes detected."
        }
        $summaryLabel.ForeColor = if ($hasChanges) { [System.Drawing.Color]::Firebrick } else { [System.Drawing.Color]::ForestGreen }
        $summaryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $summaryLabel.Location = New-Object System.Drawing.Point(100, 53)
        $summaryLabel.Size = New-Object System.Drawing.Size(690, 26)
        $summaryLabel.Anchor = "Top,Left,Right"

        $header.Controls.AddRange(@($iconLabel, $headingLabel, $summaryLabel))
        $page.Controls.Add($detailsBox)
        $page.Controls.Add($header)
        [void]$resultsTabs.TabPages.Add($page)

        $card = New-Object System.Windows.Forms.Button
        $card.Text = "$($iconLabel.Text)  $($shortNames[$sectionName])`r`n$($summaryLabel.Text)"
        $card.TextAlign = "MiddleLeft"
        $card.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $card.Size = New-Object System.Drawing.Size(245, 74)
        $card.Margin = New-Object System.Windows.Forms.Padding(7)
        $card.UseVisualStyleBackColor = $false
        $card.BackColor = if ($hasChanges) {
            [System.Drawing.Color]::MistyRose
        } else {
            [System.Drawing.Color]::Honeydew
        }
        $card.ForeColor = if ($hasChanges) {
            [System.Drawing.Color]::Firebrick
        } else {
            [System.Drawing.Color]::ForestGreen
        }
        $card.Tag = $page
        $card.Add_Click({
            param($sender, $eventArgs)
            $resultsTabs.SelectedTab = $sender.Tag
        })
        $overviewPanel.Controls.Add($card)
    }

    $fullReportBox.Text = $ReportText
    [void]$resultsTabs.TabPages.Add($fullReportPage)
    $resultsTabs.SelectedTab = $overviewPage
    return $changedSections
}

function Complete-ScriptOperation {
    param($Result, [string]$ErrorMessage)

    $script:operationTimer.Stop()
    $snapshotButton.Enabled = $true
    $refreshButton.Enabled = $true
    $compareButton.Enabled = $true
    $openFolderButton.Enabled = $true

    if ($ErrorMessage) {
        $statusLabel.Text = "Operation failed."
        Set-FullReportView -Text $ErrorMessage
        [System.Windows.Forms.MessageBox]::Show(
            $ErrorMessage,
            "PostRunCheck error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    if ($result.Action -eq "Snapshot") {
        try {
            Update-SnapshotLists -PreferredPath $result.SnapshotPath
        } catch {
            $statusLabel.Text = "Snapshot saved, but the snapshot list could not be refreshed."
            Set-FullReportView -Text "Snapshot saved to:`r`n$($result.SnapshotPath)`r`n`r`nCould not refresh the snapshot list:`r`n$($_.Exception.Message)"
            return
        }
        if ([string]::IsNullOrWhiteSpace($result.Errors)) {
            $statusLabel.Text = "Snapshot saved: $($result.SnapshotPath)"
            Set-FullReportView -Text "Snapshot saved to:`r`n$($result.SnapshotPath)`r`n`r`n$($result.Output.Trim())"
        } else {
            $statusLabel.Text = "Snapshot saved with collection errors; review the details."
            Set-FullReportView -Text "Snapshot saved to:`r`n$($result.SnapshotPath)`r`n`r`nCollection errors:`r`n$($result.Errors.Trim())`r`n`r`n$($result.Output.Trim())"
        }
    } else {
        if (-not (Test-Path -LiteralPath $result.ReportPath -PathType Leaf)) {
            $statusLabel.Text = "Comparison report was not created."
            Set-FullReportView -Text "Expected report not found: $($result.ReportPath)`r`n`r`n$($result.Output)"
            return
        }
        try {
            $reportText = Get-Content -LiteralPath $result.ReportPath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($result.Errors)) {
                $changedSections = Show-ComparisonResults -ReportText $reportText
                if ($changedSections -eq 0) {
                    $statusLabel.ForeColor = [System.Drawing.Color]::ForestGreen
                    $statusLabel.Text = "No changes detected across the compared sections."
                } else {
                    $statusLabel.ForeColor = [System.Drawing.Color]::Firebrick
                    $statusLabel.Text = "Changes found in $changedSections section(s). Select a flagged tab to investigate."
                }
            } else {
                $reportText += "`r`n`r`nPowerShell errors:`r`n$($result.Errors.Trim())"
                [void](Show-ComparisonResults -ReportText $reportText)
                $statusLabel.ForeColor = [System.Drawing.Color]::Firebrick
                $statusLabel.Text = "Comparison completed with errors; review the full report."
            }
        } catch {
            $statusLabel.Text = "Could not read the comparison report."
            Set-FullReportView -Text "Report created at $($result.ReportPath), but could not be read:`r`n$($_.Exception.Message)"
        }
    }
}

$script:currentOperation = $null
$script:operationTimer = New-Object System.Windows.Forms.Timer
$script:operationTimer.Interval = 200
$script:operationTimer.add_Tick({
    $operation = $script:currentOperation
    if (-not $operation -or -not $operation.Process.HasExited) {
        return
    }

    $script:operationTimer.Stop()
    try {
        $output = $operation.OutputTask.Result
        $errors = $operation.ErrorTask.Result
        $exitCode = $operation.Process.ExitCode
        if ($exitCode -ne 0) {
            $details = $errors.Trim()
            if ([string]::IsNullOrWhiteSpace($details)) {
                $details = $output.Trim()
            }
            throw "PowerShell exited with code $exitCode.`r`n$details"
        }

        $result = [PSCustomObject]@{
            Action = $operation.Action
            Output = $output
            Errors = $errors
            ReportPath = $operation.ReportPath
            SnapshotPath = $operation.SnapshotPath
        }
        $script:currentOperation = $null
        $operation.Process.Dispose()
        Complete-ScriptOperation -Result $result
    } catch {
        $script:currentOperation = $null
        $operation.Process.Dispose()
        Complete-ScriptOperation -ErrorMessage $_.Exception.Message
    }
})

function Set-ControlsBusy {
    param([string]$Message)

    $snapshotButton.Enabled = $false
    $refreshButton.Enabled = $false
    $compareButton.Enabled = $false
    $openFolderButton.Enabled = $false
    $statusLabel.Text = $Message
    $statusLabel.ForeColor = [System.Drawing.SystemColors]::ControlText
    Set-FullReportView -Text "Working... This may take a few seconds."
}

function Start-ScriptOperation {
    param(
        [string]$Action,
        [string]$ScriptPath,
        [string]$Parameters,
        [string]$SnapshotPath,
        [string]$ReportPath,
        [string]$Status
    )

    if ($script:currentOperation) {
        return
    }

    try {
        $process = $null
        $powerShellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
            throw "Windows PowerShell was not found at $powerShellExe"
        }

        $arguments = '-NoProfile -ExecutionPolicy Bypass -File ' +
            (ConvertTo-ProcessArgument -Value $ScriptPath) + ' ' + $Parameters
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powerShellExe
        $startInfo.Arguments = $arguments
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            $process.Dispose()
            throw "Could not start Windows PowerShell."
        }

        $script:currentOperation = [PSCustomObject]@{
            Action = $Action
            ErrorTask = $process.StandardError.ReadToEndAsync()
            OutputTask = $process.StandardOutput.ReadToEndAsync()
            Process = $process
            ReportPath = $ReportPath
            SnapshotPath = $SnapshotPath
        }
        Set-ControlsBusy -Message $Status
        $script:operationTimer.Start()
    } catch {
        if ($process) {
            $process.Dispose()
        }
        Complete-ScriptOperation -ErrorMessage $_.Exception.Message
    }
}

function Update-SnapshotLists {
    param([string]$PreferredPath)

    $previousBaseline = $baselineCombo.SelectedItem
    $previousAfter = $afterCombo.SelectedItem
    $directories = @(Get-SnapshotDirectories)
    $baselineCombo.Items.Clear()
    $afterCombo.Items.Clear()
    foreach ($directory in $directories) {
        [void]$baselineCombo.Items.Add($directory.FullName)
        [void]$afterCombo.Items.Add($directory.FullName)
    }

    if ($directories.Count -eq 0) {
        return
    }

    if ($PreferredPath -and $afterCombo.Items.Contains($PreferredPath)) {
        $afterCombo.SelectedItem = $PreferredPath
    } elseif ($previousAfter -and $afterCombo.Items.Contains($previousAfter)) {
        $afterCombo.SelectedItem = $previousAfter
    } else {
        $afterCombo.SelectedIndex = 0
    }

    if ($previousBaseline -and $baselineCombo.Items.Contains($previousBaseline)) {
        $baselineCombo.SelectedItem = $previousBaseline
    } elseif ($directories.Count -gt 1) {
        $baselineCombo.SelectedIndex = 1
    } else {
        $baselineCombo.SelectedIndex = 0
    }
}

$snapshotButton.Add_Click({
    $snapshotBase = "C:\PostRunChecks_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')"
    $snapshotPath = $snapshotBase
    $suffix = 1
    while (Test-Path -LiteralPath $snapshotPath) {
        $snapshotPath = "${snapshotBase}_$suffix"
        $suffix++
    }
    $parameters = '-OutputDirectory ' + (ConvertTo-ProcessArgument -Value $snapshotPath)
    Start-ScriptOperation -Action "Snapshot" -ScriptPath $snapshotScript `
        -Parameters $parameters -SnapshotPath $snapshotPath -Status "Taking snapshot..."
})

$refreshButton.Add_Click({
    try {
        Update-SnapshotLists
        $statusLabel.Text = "Found $($baselineCombo.Items.Count) snapshot(s) in C:\."
    } catch {
        $statusLabel.Text = "Could not list snapshots."
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, "PostRunCheck error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$compareButton.Add_Click({
    $baselinePath = [string]$baselineCombo.SelectedItem
    $afterPath = [string]$afterCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($baselinePath) -or [string]::IsNullOrWhiteSpace($afterPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Take at least one snapshot and select a baseline and an after snapshot.",
            "Select snapshots",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    if ($baselinePath -eq $afterPath) {
        [System.Windows.Forms.MessageBox]::Show(
            "Choose two different snapshots to compare.",
            "Select snapshots",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $reportPath = Join-Path $afterPath ("SuspiciousChangesReport_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss_fff"))
    $parameters = '-BaselinePath ' + (ConvertTo-ProcessArgument -Value $baselinePath) +
        ' -AfterPath ' + (ConvertTo-ProcessArgument -Value $afterPath) +
        ' -ReportPath ' + (ConvertTo-ProcessArgument -Value $reportPath)
    Start-ScriptOperation -Action "Compare" -ScriptPath $compareScript `
        -Parameters $parameters -ReportPath $reportPath -Status "Comparing snapshots..."
})

$openFolderButton.Add_Click({
    $selectedPath = [string]$afterCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Select a snapshot first.", "Select snapshot",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    Start-Process -FilePath "explorer.exe" -ArgumentList (ConvertTo-ProcessArgument -Value $selectedPath)
})

try {
    Update-SnapshotLists
} catch {
    $statusLabel.Text = "Could not list snapshots from C:\."
}

[void]$form.ShowDialog()
$script:operationTimer.Dispose()
