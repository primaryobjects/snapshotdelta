$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$executable = Join-Path $projectRoot "dist\SnapshotDelta.exe"
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "SnapshotDelta.exe was not built at $executable"
}

$application = Start-Process -FilePath $executable -PassThru -Wait
if ($application.ExitCode -ne 0) {
    throw "SnapshotDelta.exe exited with code $($application.ExitCode)"
}
