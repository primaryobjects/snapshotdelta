param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "dist\SnapshotDelta.exe")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot "src\SnapshotDeltaLauncher.cs"
$iconPath = Join-Path $projectRoot "images\delta.png"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Launcher source not found: $sourcePath"
}
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw "Application icon not found: $iconPath"
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$temporaryPath = Join-Path $outputDirectory ([System.IO.Path]::GetRandomFileName() + ".exe")
$temporaryIconPath = Join-Path $outputDirectory ([System.IO.Path]::GetRandomFileName() + ".ico")
$bitmap = $null
$iconBitmap = $null
$graphics = $null
$icon = $null
$iconStream = $null
$provider = $null
try {
    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::FromFile($iconPath)
    $iconBitmap = New-Object System.Drawing.Bitmap(32, 32, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($bitmap, 0, 0, 32, 32)
    $iconHandle = $iconBitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    $iconStream = [System.IO.File]::Create($temporaryIconPath)
    $icon.Save($iconStream)
    $iconStream.Dispose()
    $iconStream = $null

    $provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
    $compilerParameters.GenerateExecutable = $true
    $compilerParameters.OutputAssembly = $temporaryPath
    $compilerParameters.CompilerOptions = '/target:winexe /win32icon:"' + $temporaryIconPath + '"'
    [void]$compilerParameters.ReferencedAssemblies.Add("System.dll")
    [void]$compilerParameters.ReferencedAssemblies.Add("System.Windows.Forms.dll")
    [void]$compilerParameters.ReferencedAssemblies.Add("System.Drawing.dll")

    $compileResults = $provider.CompileAssemblyFromFile($compilerParameters, $sourcePath)
    if ($compileResults.Errors.HasErrors) {
        $messages = @($compileResults.Errors | ForEach-Object { $_.ToString() })
        throw "Could not compile SnapshotDelta:`r`n$($messages -join "`r`n")"
    }

    Move-Item -LiteralPath $temporaryPath -Destination $resolvedOutputPath -Force
    Write-Output "Built $resolvedOutputPath"
} finally {
    if ($iconStream) { $iconStream.Dispose() }
    if ($icon) { $icon.Dispose() }
    if ($graphics) { $graphics.Dispose() }
    if ($iconBitmap) { $iconBitmap.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if ($provider) { $provider.Dispose() }
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    if (Test-Path -LiteralPath $temporaryIconPath) {
        Remove-Item -LiteralPath $temporaryIconPath -Force
    }
}
