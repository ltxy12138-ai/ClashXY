[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReleaseDirectory,
    [string]$ExpectedVersion,
    [string]$ExpectedCoreSha256 = 'CF894375DBC00AB6708C1314AC35BBD29059F4C37F315353AACA7F1A9C566DE6',
    [switch]$RequireValidSignature,
    [string]$ExpectedPublisherPattern
)

$ErrorActionPreference = 'Stop'
$release = [System.IO.Path]::GetFullPath($ReleaseDirectory)
if (-not (Test-Path -LiteralPath $release -PathType Container)) {
    throw "Release directory does not exist: $release"
}

$required = @(
    'ClashXY.exe',
    'flutter_windows.dll',
    'data\app.so',
    'data\flutter_assets\AssetManifest.bin',
    'data\flutter_assets\assets\core\mihomo.exe',
    'data\flutter_assets\assets\licenses\mihomo-GPL-3.0.txt',
    'data\flutter_assets\NOTICES.Z'
)
foreach ($relative in $required) {
    $candidate = Join-Path $release $relative
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Release is missing required file: $relative"
    }
}

$application = Join-Path $release 'ClashXY.exe'
if ($RequireValidSignature -and [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
    throw '-ExpectedPublisherPattern is required with -RequireValidSignature.'
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern) -and -not $RequireValidSignature) {
    throw '-ExpectedPublisherPattern requires -RequireValidSignature.'
}
if ($RequireValidSignature) {
    $verifyArguments = @{ Path = @($application) }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
        $verifyArguments.ExpectedPublisherPattern = $ExpectedPublisherPattern
    }
    & (Join-Path $PSScriptRoot 'verify_windows_signatures.ps1') @verifyArguments | Out-Host
}
$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($application)
if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion) -and $version.ProductVersion -ne $ExpectedVersion) {
    throw "ClashXY.exe product version '$($version.ProductVersion)' did not match '$ExpectedVersion'."
}
if ($version.ProductName -ne 'ClashXY') {
    throw "Unexpected product name '$($version.ProductName)'."
}

$core = Join-Path $release 'data\flutter_assets\assets\core\mihomo.exe'
$coreHash = (Get-FileHash -LiteralPath $core -Algorithm SHA256).Hash
if ($coreHash -ne $ExpectedCoreSha256) {
    throw 'Bundled Mihomo SHA-256 did not match the verified release digest.'
}

$mt = Get-ChildItem -LiteralPath 'C:\Program Files (x86)\Windows Kits\10\bin' -Filter mt.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\mt\.exe$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if ($null -eq $mt) {
    throw 'Windows SDK mt.exe is required to verify the embedded application manifest.'
}
$manifest = Join-Path ([System.IO.Path]::GetTempPath()) ("clashxy-manifest-" + [guid]::NewGuid().ToString('N') + '.xml')
try {
    & $mt.FullName -nologo "-inputresource:$application;#1" "-out:$manifest"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $manifest)) {
        throw 'Windows SDK could not extract the ClashXY application manifest.'
    }
    $manifestText = Get-Content -LiteralPath $manifest -Raw
    if (-not $manifestText.Contains('requireAdministrator')) {
        throw 'ClashXY.exe does not contain the requireAdministrator manifest marker.'
    }
} finally {
    if (Test-Path -LiteralPath $manifest) {
        Remove-Item -LiteralPath $manifest -Force
    }
}

[pscustomobject]@{
    Application        = $application
    ProductVersion     = $version.ProductVersion
    FileVersion        = $version.FileVersion
    CoreSHA256         = $coreHash
    RequiresAdmin      = $true
    RequiredFileCount  = $required.Count
}
