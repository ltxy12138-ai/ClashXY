[CmdletBinding()]
param(
    [string]$Flutter = 'flutter',
    [string]$Iscc,
    [switch]$SkipBuild,
    [string]$SignToolCommand,
    [string]$ExpectedPublisherPattern
)

$ErrorActionPreference = 'Stop'
if (-not [string]::IsNullOrWhiteSpace($SignToolCommand) -and
    [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
    throw '-ExpectedPublisherPattern is required whenever -SignToolCommand is used.'
}
if ([string]::IsNullOrWhiteSpace($SignToolCommand) -and
    -not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
    throw '-ExpectedPublisherPattern cannot be used without -SignToolCommand.'
}
$repository = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pubspec = Join-Path $repository 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspec -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$' | Select-Object -First 1
if ($null -eq $versionLine) {
    throw 'pubspec.yaml must contain a semantic version and numeric build, for example 1.9.1+15.'
}
$appVersion = $versionLine.Matches[0].Groups[1].Value
$appBuild = $versionLine.Matches[0].Groups[2].Value

if (-not $SkipBuild) {
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows build failed with exit code $LASTEXITCODE."
    }
}

$release = [System.IO.Path]::GetFullPath((Join-Path $repository 'build\windows\x64\runner\Release'))
if (-not (Test-Path -LiteralPath (Join-Path $release 'ClashXY.exe'))) {
    throw "Expected release executable was not found under $release."
}

if ([string]::IsNullOrWhiteSpace($Iscc)) {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $Iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($Iscc) -or -not (Test-Path -LiteralPath $Iscc)) {
    throw 'Inno Setup 6 compiler was not found. Install JRSoftware.InnoSetup or pass -Iscc.'
}
$compiler = [System.IO.Path]::GetFullPath($Iscc)
$script = [System.IO.Path]::GetFullPath((Join-Path $repository 'installer\ClashXY.iss'))
$dist = [System.IO.Path]::GetFullPath((Join-Path $repository 'dist'))
[System.IO.Directory]::CreateDirectory($dist) | Out-Null
$installer = Join-Path $dist "ClashXY-Setup-x64-$appVersion-build$appBuild.exe"
if (Test-Path -LiteralPath $installer) {
    throw "Installer already exists: $installer"
}

$arguments = @(
    '/Qp',
    "/DAppVersion=$appVersion",
    "/DAppBuild=$appBuild",
    "/DSourceDir=$release",
    "/DOutputDir=$dist"
)
if (-not [string]::IsNullOrWhiteSpace($SignToolCommand)) {
    $arguments += "/Sclashxy=$SignToolCommand"
    $arguments += '/DSignToolName=clashxy'
}
$arguments += $script

& $compiler @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $installer)) {
    throw "Expected installer was not created: $installer"
}

$signatureResults = @()
if (-not [string]::IsNullOrWhiteSpace($SignToolCommand)) {
    $verifier = Join-Path $PSScriptRoot 'verify_windows_signatures.ps1'
    $verifyArguments = @{
        Path = @(
            (Join-Path $release 'ClashXY.exe'),
            $installer
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
        $verifyArguments.ExpectedPublisherPattern = $ExpectedPublisherPattern
    }
    $signatureResults = @(& $verifier @verifyArguments)
    $publishers = @($signatureResults | ForEach-Object { $_.Publisher } | Sort-Object -Unique)
    if ($publishers.Count -ne 1) {
        throw 'ClashXY.exe and the installer must have the same Authenticode publisher.'
    }
}

$hash = Get-FileHash -LiteralPath $installer -Algorithm SHA256
[pscustomobject]@{
    Installer = $installer
    SHA256    = $hash.Hash
    Signed    = -not [string]::IsNullOrWhiteSpace($SignToolCommand)
    SignaturesVerified = $signatureResults.Count
}
