[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$EvidenceDirectory,
    [Parameter(Mandatory)]
    [string]$ExpectedInstallerSHA256,
    [Parameter(Mandatory)]
    [string]$ExpectedVersion,
    [Parameter(Mandatory)]
    [string]$ExpectedSourceCommit,
    [Parameter(Mandatory)]
    [string]$ExpectedPublisherPattern,
    [switch]$AllowSingleOs
)

$ErrorActionPreference = 'Stop'
if ($ExpectedInstallerSHA256 -notmatch '^[0-9A-Fa-f]{64}$') {
    throw '-ExpectedInstallerSHA256 must be a 64-character hexadecimal SHA-256 digest.'
}
if ($ExpectedVersion -notmatch '^\d+\.\d+\.\d+\+\d+$') {
    throw '-ExpectedVersion must use <major>.<minor>.<patch>+<build> format.'
}
if ($ExpectedSourceCommit -notmatch '^[0-9A-Fa-f]{40}$') {
    throw '-ExpectedSourceCommit must be a full 40-character Git commit.'
}
try {
    [void][regex]::new($ExpectedPublisherPattern)
} catch {
    throw '-ExpectedPublisherPattern must be a valid regular expression.'
}
$states = @()
$requiredCheckpoints = @(
    'clean-machine-baseline',
    'install',
    'first-launch',
    'subscription-import',
    'subscription-connect',
    'node-switch',
    'internet-access',
    'subscription-update',
    'yaml-import',
    'profile-switch',
    'app-before-restart',
    'app-restart-restore',
    'sleep-before',
    'sleep-resume',
    'network-before-switch',
    'network-switch-recovery',
    'system-before-restart',
    'system-restart-autoconnect',
    'disconnect-cleanup',
    'uninstall-cleanup'
)

foreach ($directoryValue in $EvidenceDirectory) {
    $directory = [System.IO.Path]::GetFullPath($directoryValue)
    $statePath = Join-Path $directory 'state.json'
    $reportPath = Join-Path $directory 'report.md'
    $manifestPath = Join-Path $directory 'evidence.sha256'
    foreach ($path in @($statePath, $reportPath, $manifestPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "P6-010 evidence file is missing: $path"
        }
    }

    $expectedHashes = @{}
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if ($line -notmatch '^([0-9A-Fa-f]{64}) \*(state\.json|report\.md)$') {
            throw "Invalid evidence manifest line in ${manifestPath}: $line"
        }
        $expectedHashes[$Matches[2]] = $Matches[1].ToUpperInvariant()
    }
    foreach ($name in @('state.json', 'report.md')) {
        $path = Join-Path $directory $name
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if (-not $expectedHashes.ContainsKey($name) -or $expectedHashes[$name] -ne $actual) {
            throw "P6-010 evidence hash mismatch: $path"
        }
    }

    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($state.SchemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace($state.CompletedAtUtc)) {
        throw "P6-010 evidence is incomplete or uses an unsupported schema: $statePath"
    }
    if (-not $state.ReleaseGateEligible -or $state.Installer.Signature.Status -ne 'Valid' -or
        -not $state.Installer.Signature.Timestamped) {
        throw "P6-010 evidence was not collected from a valid timestamped release installer: $statePath"
    }
    if ([string]::IsNullOrWhiteSpace($state.ExpectedPublisherPattern) -or
        $state.Installer.Signature.Publisher -notmatch $state.ExpectedPublisherPattern) {
        throw "P6-010 evidence lacks an explicit matching publisher pattern: $statePath"
    }
    if ($state.Environment.Architecture -notmatch '64') {
        throw "P6-010 evidence is not from Windows x64: $statePath"
    }
    $declaredCheckpoints = @($state.RequiredCheckpoints | Sort-Object -Unique)
    if (Compare-Object -ReferenceObject $requiredCheckpoints -DifferenceObject $declaredCheckpoints) {
        throw "P6-010 evidence declares an unexpected required-checkpoint set: $statePath"
    }
    foreach ($checkpoint in $requiredCheckpoints) {
        $record = @($state.Checkpoints | Where-Object { $_.Name -eq $checkpoint }) | Select-Object -First 1
        if ($null -eq $record -or $record.Result -ne 'Pass') {
            throw "P6-010 checkpoint did not pass in ${statePath}: $checkpoint"
        }
    }
    if ($state.Installer.SHA256 -ne $ExpectedInstallerSHA256.ToUpperInvariant()) {
        throw "Installer SHA-256 mismatch in $statePath."
    }
    if ($state.ExpectedVersion -ne $ExpectedVersion) {
        throw "Expected version mismatch in $statePath."
    }
    if ($state.Installer.Signature.Publisher -notmatch $ExpectedPublisherPattern) {
        throw "Publisher mismatch in $statePath."
    }
    $states += $state
}

$hashes = @($states | ForEach-Object { $_.Installer.SHA256 } | Sort-Object -Unique)
$versions = @($states | ForEach-Object { $_.ExpectedVersion } | Sort-Object -Unique)
$publishers = @($states | ForEach-Object { $_.Installer.Signature.Publisher } | Sort-Object -Unique)
$commits = @($states | ForEach-Object { $_.SourceCommit } | Sort-Object -Unique)
if ($hashes.Count -ne 1 -or $versions.Count -ne 1 -or $publishers.Count -ne 1 -or $commits.Count -ne 1) {
    throw 'All P6-010 runs must use the exact same source commit, installer hash, version, and Authenticode publisher.'
}
if ($commits[0] -notmatch '^[0-9a-f]{40}$') {
    throw 'P6-010 evidence does not contain an exact Git source commit.'
}
if ($commits[0] -ne $ExpectedSourceCommit.ToLowerInvariant()) {
    throw 'P6-010 source commit does not match the expected release commit.'
}

$families = @($states | ForEach-Object {
    $build = [int]$_.Environment.BuildNumber
    if ($_.Environment.Caption -match 'Windows 11' -or $build -ge 22000) { 'Windows 11' }
    elseif ($_.Environment.Caption -match 'Windows 10') { 'Windows 10' }
    else { 'Unsupported' }
} | Sort-Object -Unique)
if ($families -contains 'Unsupported') {
    throw 'P6-010 evidence includes an unsupported Windows family.'
}
if (-not $AllowSingleOs -and ($families -notcontains 'Windows 10' -or $families -notcontains 'Windows 11')) {
    throw 'Final P6-010 evidence must include both Windows 10 x64 and Windows 11 x64.'
}

[pscustomobject]@{
    Runs             = $states.Count
    WindowsFamilies  = $families -join ', '
    ExpectedVersion  = $versions[0]
    SourceCommit     = $commits[0]
    InstallerSHA256  = $hashes[0]
    Publisher        = $publishers[0]
    AllChecksPassed  = $true
}
