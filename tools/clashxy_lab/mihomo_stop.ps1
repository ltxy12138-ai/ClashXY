[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RuntimeDirectory,

    [string]$StatePath,

    [ValidateRange(1, 60)]
    [int]$ShutdownTimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsPathWithinDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $relative = [System.IO.Path]::GetRelativePath($Directory, $Path)
    if ([System.IO.Path]::IsPathRooted($relative) -or $relative -eq '..') {
        return $false
    }
    $parentPrefix = '..' + [System.IO.Path]::DirectorySeparatorChar
    return -not $relative.StartsWith($parentPrefix, [System.StringComparison]::Ordinal)
}

function Get-RunningProcess {
    param([Parameter(Mandatory)][int]$Id)

    try {
        return Get-Process -Id $Id -ErrorAction Stop
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        return $null
    }
}

if (-not [System.OperatingSystem]::IsWindows()) {
    throw 'Mihomo Windows process control requires Windows.'
}

$runtimeFullPath = [System.IO.Path]::GetFullPath($RuntimeDirectory)
$stateFullPath = if ([string]::IsNullOrWhiteSpace($StatePath)) {
    Join-Path $runtimeFullPath 'mihomo-process.json'
}
else {
    [System.IO.Path]::GetFullPath($StatePath)
}
if (-not (Test-IsPathWithinDirectory -Directory $runtimeFullPath -Path $stateFullPath)) {
    throw 'StatePath must remain inside RuntimeDirectory.'
}
if ([System.IO.Path]::GetExtension($stateFullPath) -ne '.json') {
    throw 'Mihomo StatePath must use .json.'
}

if (-not [System.IO.File]::Exists($stateFullPath)) {
    return [pscustomobject][ordered]@{
        SchemaVersion  = 1
        Stopped        = $false
        AlreadyStopped = $true
        Pid            = $null
        StatePath      = $stateFullPath
    }
}

try {
    $state = [System.IO.File]::ReadAllText($stateFullPath) | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw 'Mihomo process state is invalid JSON.'
}
foreach ($propertyName in @('SchemaVersion', 'Pid', 'CorePath', 'StartTimeUtcTicks')) {
    if ($null -eq $state.PSObject.Properties[$propertyName]) {
        throw ('Mihomo process state is missing ' + $propertyName + '.')
    }
}
if ([int]$state.SchemaVersion -ne 1) {
    throw 'Unsupported Mihomo process state schema.'
}

$pidValue = [int]$state.Pid
$process = Get-RunningProcess -Id $pidValue
if ($null -eq $process) {
    [System.IO.File]::Delete($stateFullPath)
    return [pscustomobject][ordered]@{
        SchemaVersion  = 1
        Stopped        = $false
        AlreadyStopped = $true
        Pid            = $pidValue
        StatePath      = $stateFullPath
    }
}

try {
    $actualCorePath = [System.IO.Path]::GetFullPath($process.Path)
}
catch {
    throw ('Cannot verify executable identity for PID ' + $pidValue + '.')
}
$expectedCorePath = [System.IO.Path]::GetFullPath([string]$state.CorePath)
if (-not $actualCorePath.Equals($expectedCorePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'State PID executable mismatch; refusing to stop an unrelated process.'
}
if ($process.StartTime.ToUniversalTime().Ticks -ne [int64]$state.StartTimeUtcTicks) {
    throw 'State PID start time mismatch; refusing to stop a reused PID.'
}

Stop-Process -Id $pidValue -ErrorAction Stop
if (-not $process.WaitForExit($ShutdownTimeoutSeconds * 1000)) {
    Stop-Process -Id $pidValue -Force -ErrorAction Stop
    if (-not $process.WaitForExit(5000)) {
        throw 'Mihomo did not stop within the shutdown timeout.'
    }
}

[System.IO.File]::Delete($stateFullPath)
[pscustomobject][ordered]@{
    SchemaVersion  = 1
    Stopped        = $true
    AlreadyStopped = $false
    Pid            = $pidValue
    StatePath      = $stateFullPath
    StoppedAtUtc   = [DateTime]::UtcNow.ToString('O')
}
