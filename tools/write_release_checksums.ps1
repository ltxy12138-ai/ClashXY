[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repository = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$versionLine = Select-String -LiteralPath (Join-Path $repository 'pubspec.yaml') -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$' | Select-Object -First 1
if ($null -eq $versionLine) {
    throw 'pubspec.yaml must contain a semantic version and numeric build.'
}
$version = $versionLine.Matches[0].Groups[1].Value
$build = $versionLine.Matches[0].Groups[2].Value
$dist = Join-Path $repository 'dist'
$artifacts = @(
    Join-Path $dist "ClashXY-Windows-x64-$version-build$build.zip"
    Join-Path $dist "ClashXY-Setup-x64-$version-build$build.exe"
)
foreach ($artifact in $artifacts) {
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
        throw "Release artifact was not found: $artifact"
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $dist "SHA256SUMS-$version-build$build.txt"
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Checksum file already exists: $resolvedOutput"
}
$lines = foreach ($artifact in $artifacts) {
    $hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([System.IO.Path]::GetFileName($artifact))"
}
[System.IO.File]::WriteAllLines($resolvedOutput, $lines, [System.Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    ChecksumFile = $resolvedOutput
    ArtifactCount = $artifacts.Count
    Lines = $lines
}
