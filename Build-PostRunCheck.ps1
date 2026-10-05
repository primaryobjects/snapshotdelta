param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "PostRunCheck.exe")
)

$ErrorActionPreference = "Stop"
$sourcePath = Join-Path $PSScriptRoot "PostRunCheckLauncher.cs"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Launcher source not found: $sourcePath"
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$temporaryPath = Join-Path $outputDirectory ([System.IO.Path]::GetRandomFileName() + ".exe")
try {
    Add-Type -Path $sourcePath `
        -ReferencedAssemblies @("System.Windows.Forms.dll", "System.Drawing.dll") `
        -OutputAssembly $temporaryPath `
        -OutputType WindowsApplication
    Move-Item -LiteralPath $temporaryPath -Destination $resolvedOutputPath -Force
    Write-Output "Built $resolvedOutputPath"
} finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}
