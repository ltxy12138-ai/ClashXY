[CmdletBinding()]
param(
    [string]$Flutter = 'flutter',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repository = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pubspec = Join-Path $repository 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspec -Pattern '^version:\s*([^\s]+)' | Select-Object -First 1
if ($null -eq $versionLine) {
    throw 'Unable to read the application version from pubspec.yaml.'
}
$version = $versionLine.Matches[0].Groups[1].Value -replace '\+', '-build'

if (-not $SkipBuild) {
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows build failed with exit code $LASTEXITCODE."
    }
}

$release = Join-Path $repository 'build\windows\x64\runner\Release'
if (-not (Test-Path -LiteralPath (Join-Path $release 'ClashXY.exe'))) {
    throw "Expected release executable was not found under $release."
}

$dist = Join-Path $repository 'dist'
[System.IO.Directory]::CreateDirectory($dist) | Out-Null
$archive = Join-Path $dist "ClashXY-Windows-x64-$version.zip"
if (Test-Path -LiteralPath $archive) {
    throw "Release archive already exists: $archive"
}

$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$staging = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot ("clashxy-package-" + [guid]::NewGuid().ToString('N')))
)
if (-not $staging.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to create a staging directory outside the Windows temporary directory.'
}

try {
    $app = Join-Path $staging 'ClashXY'
    Copy-Item -LiteralPath $release -Destination $app -Recurse
    $licenses = Join-Path $app 'licenses'
    [System.IO.Directory]::CreateDirectory($licenses) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'THIRD_PARTY_NOTICES.md') -Destination $licenses
    Copy-Item -LiteralPath (Join-Path $repository 'LICENSE') -Destination $licenses
    Copy-Item -LiteralPath (Join-Path $repository 'NOTICE.md') -Destination $licenses
    Copy-Item -LiteralPath (Join-Path $repository 'PRIVACY.md') -Destination $licenses
    Copy-Item -LiteralPath (Join-Path $repository 'SECURITY.md') -Destination $licenses
    Copy-Item -LiteralPath (Join-Path $repository 'README.md') -Destination $app
    Copy-Item -LiteralPath (Join-Path $repository 'assets\licenses\mihomo-GPL-3.0.txt') -Destination $licenses
    Compress-Archive -LiteralPath $app -DestinationPath $archive -CompressionLevel Optimal
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}

$hash = Get-FileHash -LiteralPath $archive -Algorithm SHA256
[pscustomobject]@{
    Archive = $archive
    SHA256  = $hash.Hash
}
