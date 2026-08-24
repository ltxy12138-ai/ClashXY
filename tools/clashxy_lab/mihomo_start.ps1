[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CorePath,

    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter(Mandatory)]
    [string]$RuntimeDirectory,

    [string]$StatePath,

    [ValidateRange(1, 60)]
    [int]$StartupTimeoutSeconds = 10
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

function Get-ProcessExecutablePath {
    param([Parameter(Mandatory)][System.Diagnostics.Process]$Process)

    try {
        return [System.IO.Path]::GetFullPath($Process.Path)
    }
    catch {
        throw ('Cannot verify executable identity for PID ' + $Process.Id + '.')
    }
}

if (-not [System.OperatingSystem]::IsWindows()) {
    throw 'Mihomo Windows process control requires Windows.'
}

$coreFullPath = [System.IO.Path]::GetFullPath($CorePath)
$configFullPath = [System.IO.Path]::GetFullPath($ConfigPath)
$runtimeFullPath = [System.IO.Path]::GetFullPath($RuntimeDirectory)

if (-not [System.IO.File]::Exists($coreFullPath)) {
    throw 'Mihomo core executable was not found.'
}
if ([System.IO.Path]::GetExtension($coreFullPath) -ne '.exe') {
    throw 'Mihomo core must be a Windows .exe file.'
}
if (-not [System.IO.File]::Exists($configFullPath)) {
    throw 'Mihomo config file was not found.'
}
if ([System.IO.Path]::GetExtension($configFullPath) -notin @('.yaml', '.yml')) {
    throw 'Mihomo config must use .yaml or .yml.'
}

[void][System.IO.Directory]::CreateDirectory($runtimeFullPath)
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
if ($stateFullPath.Equals($coreFullPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $stateFullPath.Equals($configFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'StatePath must not overwrite the core or config file.'
}
[void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($stateFullPath))

if ([System.IO.File]::Exists($stateFullPath)) {
    try {
        $existingState = [System.IO.File]::ReadAllText($stateFullPath) | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw 'Existing Mihomo process state is invalid JSON.'
    }
    if ($null -eq $existingState.PSObject.Properties['Pid'] -or
        $null -eq $existingState.PSObject.Properties['CorePath'] -or
        $null -eq $existingState.PSObject.Properties['StartTimeUtcTicks']) {
        throw 'Existing Mihomo process state is incomplete.'
    }

    $existingProcess = Get-RunningProcess -Id ([int]$existingState.Pid)
    if ($null -ne $existingProcess) {
        $existingPath = Get-ProcessExecutablePath -Process $existingProcess
        $pathMatches = $existingPath.Equals(
            [System.IO.Path]::GetFullPath([string]$existingState.CorePath),
            [System.StringComparison]::OrdinalIgnoreCase
        )
        $timeMatches = $existingProcess.StartTime.ToUniversalTime().Ticks -eq [int64]$existingState.StartTimeUtcTicks
        if (-not $pathMatches -or -not $timeMatches) {
            throw 'Existing state PID belongs to a different process; refusing to overwrite it.'
        }

        return [pscustomobject][ordered]@{
            SchemaVersion    = 1
            Started          = $false
            AlreadyRunning   = $true
            Pid              = $existingProcess.Id
            CorePath         = $existingPath
            ConfigPath       = [string]$existingState.ConfigPath
            RuntimeDirectory = $runtimeFullPath
            StatePath        = $stateFullPath
            StartedAtUtc     = [string]$existingState.StartedAtUtc
        }
    }

    [System.IO.File]::Delete($stateFullPath)
}

$null = @(& $coreFullPath -t -f $configFullPath -d $runtimeFullPath 2>&1)
$validationExitCode = $LASTEXITCODE
if ($validationExitCode -ne 0) {
    throw ('Mihomo configuration validation failed with exit code ' + $validationExitCode + '.')
}

$stdoutPath = Join-Path $runtimeFullPath 'mihomo.stdout.log'
$stderrPath = Join-Path $runtimeFullPath 'mihomo.stderr.log'
$quotedRuntime = '"' + $runtimeFullPath + '"'
$quotedConfig = '"' + $configFullPath + '"'
$process = Start-Process -FilePath $coreFullPath -ArgumentList @('-d', $quotedRuntime, '-f', $quotedConfig) -WorkingDirectory $runtimeFullPath -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru

try {
    $earlyExitMilliseconds = [Math]::Min($StartupTimeoutSeconds * 1000, 1000)
    if ($process.WaitForExit($earlyExitMilliseconds)) {
        throw ('Mihomo exited during startup with code ' + $process.ExitCode + '.')
    }
    $process.Refresh()
    $startedAtUtc = $process.StartTime.ToUniversalTime()
    $processPath = Get-ProcessExecutablePath -Process $process
    if (-not $processPath.Equals($coreFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Started process executable identity does not match CorePath.'
    }

    $state = [ordered]@{
        SchemaVersion     = 1
        Pid               = $process.Id
        CorePath          = $coreFullPath
        ConfigPath        = $configFullPath
        RuntimeDirectory  = $runtimeFullPath
        StartedAtUtc      = $startedAtUtc.ToString('O')
        StartTimeUtcTicks = $startedAtUtc.Ticks
        StdoutPath        = $stdoutPath
        StderrPath        = $stderrPath
    }
    $temporaryStatePath = Join-Path ([System.IO.Path]::GetDirectoryName($stateFullPath)) ('.' + [System.IO.Path]::GetFileName($stateFullPath) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $stateJson = $state | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($temporaryStatePath, $stateJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Move($temporaryStatePath, $stateFullPath, $true)
    }
    finally {
        if ([System.IO.File]::Exists($temporaryStatePath)) {
            [System.IO.File]::Delete($temporaryStatePath)
        }
    }

    [pscustomobject][ordered]@{
        SchemaVersion    = 1
        Started          = $true
        AlreadyRunning   = $false
        Pid              = $process.Id
        CorePath         = $coreFullPath
        ConfigPath       = $configFullPath
        RuntimeDirectory = $runtimeFullPath
        StatePath        = $stateFullPath
        StartedAtUtc     = $startedAtUtc.ToString('O')
    }
}
catch {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    throw
}
