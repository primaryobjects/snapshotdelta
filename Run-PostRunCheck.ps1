$ErrorActionPreference = "Stop"
$executable = Join-Path $PSScriptRoot "PostRunCheck.exe"
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "PostRunCheck.exe was not built at $executable"
}

$application = Start-Process -FilePath $executable -PassThru -Wait
if ($application.ExitCode -ne 0) {
    throw "PostRunCheck.exe exited with code $($application.ExitCode)"
}
