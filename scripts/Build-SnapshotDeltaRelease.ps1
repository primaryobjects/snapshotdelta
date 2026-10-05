param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "release\SnapshotDelta.zip")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
$stageDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("SnapshotDeltaRelease_" + [guid]::NewGuid().ToString("N"))
$temporaryArchive = Join-Path $outputDirectory ([guid]::NewGuid().ToString("N") + ".zip")

$packageFiles = @(
    @{ Source = "readme.md"; Destination = "README.md" }
    @{ Source = "dist\SnapshotDelta.exe"; Destination = "SnapshotDelta.exe" }
    @{ Source = "scripts\SnapshotDelta-GUI.ps1"; Destination = "scripts\SnapshotDelta-GUI.ps1" }
    @{ Source = "scripts\Capture-Snapshot.ps1"; Destination = "scripts\Capture-Snapshot.ps1" }
    @{ Source = "scripts\Compare-Snapshots.ps1"; Destination = "scripts\Compare-Snapshots.ps1" }
    @{ Source = "images\delta.png"; Destination = "images\delta.png" }
    @{ Source = "images\screenshot.png"; Destination = "images\screenshot.png" }
)

try {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "dist\SnapshotDelta.exe") -PathType Leaf)) {
        throw "SnapshotDelta.exe was not found. Build the app before creating the release ZIP."
    }

    foreach ($file in $packageFiles) {
        $sourcePath = Join-Path $projectRoot $file.Source
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Required release file not found: $sourcePath"
        }
    }

    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $stageDirectory -Force | Out-Null

    foreach ($file in $packageFiles) {
        $sourcePath = Join-Path $projectRoot $file.Source
        $destinationPath = Join-Path $stageDirectory $file.Destination
        $destinationDirectory = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
    }

    Compress-Archive -Path (Join-Path $stageDirectory "*") -DestinationPath $temporaryArchive -CompressionLevel Optimal
    Move-Item -LiteralPath $temporaryArchive -Destination $resolvedOutputPath -Force
    Write-Output "Built release package: $resolvedOutputPath"
} finally {
    if (Test-Path -LiteralPath $temporaryArchive) {
        Remove-Item -LiteralPath $temporaryArchive -Force
    }
    if (Test-Path -LiteralPath $stageDirectory) {
        Remove-Item -LiteralPath $stageDirectory -Recurse -Force
    }
}
