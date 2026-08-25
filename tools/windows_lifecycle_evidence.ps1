[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Start', 'Record', 'Status', 'Finish')]
    [string]$Action,
    [string]$EvidenceDirectory,
    [string]$InstallerPath,
    [string]$ExpectedVersion,
    [string]$ExpectedPublisherPattern,
    [string]$TunDeviceName = 'ClashXY',
    [string]$Checkpoint,
    [ValidateSet('Pass', 'Fail', 'Blocked')]
    [string]$Result,
    [string]$Notes,
    [switch]$AllowUnsignedCandidate
)

$ErrorActionPreference = 'Stop'
$repository = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
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
$optionalCheckpoints = @(
    'two-sui-login',
    'two-sui-device-create',
    'two-sui-connect',
    'two-sui-device-delete'
)

function ConvertTo-UtcText {
    param([datetime]$Value)
    return $Value.ToUniversalTime().ToString('o')
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Protect-EvidenceText {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $safe = $Value -replace '(?i)https?://\S+', '[REDACTED_URL]'
    $safe = $safe -replace '(?i)\b(password|passwd|token|secret|authorization|uuid)\s*[:=]\s*\S+', '$1=[REDACTED]'
    $safe = $safe -replace '(?i)\b[0-9a-f]{32,}\b', '[REDACTED_TOKEN]'
    $safe = $safe -replace '(?i)C:\\Users\\[^\\\s]+', '%USERPROFILE%'
    return $safe.Trim()
}

function Get-TextFingerprint {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) {
        return $null
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
        return $hash.Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

function Get-FileEvidence {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $item = Get-Item -LiteralPath $Path
    $signature = Get-AuthenticodeSignature -LiteralPath $item.FullName
    [pscustomobject]@{
        Name        = $item.Name
        Size        = $item.Length
        SHA256      = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        FileVersion = $item.VersionInfo.FileVersion
        ProductVersion = $item.VersionInfo.ProductVersion
        Signature   = [pscustomobject]@{
            Status      = $signature.Status.ToString()
            Publisher   = $(if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null })
            Thumbprint  = $(if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null })
            Timestamped = $null -ne $signature.TimeStamperCertificate
        }
    }
}

function Get-InstalledEvidence {
    $key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{B653B669-E2AB-4D8C-9F65-E642A15D3B45}_is1'
    if (-not (Test-Path -LiteralPath $key)) {
        return [pscustomobject]@{ Present = $false; DisplayVersion = $null; Executable = $null; Uninstaller = $null }
    }
    $entry = Get-ItemProperty -LiteralPath $key
    $location = [string]$entry.InstallLocation
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = Split-Path ([string]$entry.UninstallString.Trim('"')) -Parent
    }
    [pscustomobject]@{
        Present        = $true
        DisplayVersion = [string]$entry.DisplayVersion
        Publisher      = [string]$entry.Publisher
        LocationHash   = Get-TextFingerprint -Value $location
        Executable     = Get-FileEvidence -Path (Join-Path $location 'ClashXY.exe')
        Uninstaller    = Get-FileEvidence -Path (Join-Path $location 'unins000.exe')
    }
}

function Get-ProcessEvidence {
    param([string]$Pattern)
    $matches = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $Pattern })
    $starts = @($matches | ForEach-Object {
        try { ConvertTo-UtcText -Value $_.StartTime } catch { $null }
    } | Where-Object { $_ } | Sort-Object)
    [pscustomobject]@{
        Count              = $matches.Count
        LatestStartTimeUtc = $(if ($starts.Count -gt 0) { $starts[-1] } else { $null })
    }
}

function Get-SystemEvents {
    param(
        [string]$LogName,
        [int[]]$Ids,
        [datetime]$StartTime,
        [string]$ProviderName
    )
    $filter = @{ LogName = $LogName; StartTime = $StartTime }
    if ($Ids.Count -gt 0) { $filter.Id = $Ids }
    if (-not [string]::IsNullOrWhiteSpace($ProviderName)) { $filter.ProviderName = $ProviderName }
    try {
        return @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop |
            Sort-Object TimeCreated |
            Select-Object -Last 50 |
            ForEach-Object {
                [pscustomobject]@{
                    Id             = $_.Id
                    Provider       = $_.ProviderName
                    TimeCreatedUtc = ConvertTo-UtcText -Value $_.TimeCreated
                }
            })
    } catch {
        return @()
    }
}

function Get-NetworkEvidence {
    $route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -ne '0.0.0.0' } |
        Sort-Object RouteMetric, InterfaceMetric |
        Select-Object -First 1
    if ($null -eq $route) {
        return [pscustomobject]@{ Present = $false; Fingerprint = $null; InterfaceIndex = $null; Status = $null }
    }
    $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
    $seed = "$($route.InterfaceIndex)|$($route.NextHop)|$($adapter.InterfaceGuid)|$($adapter.Status)"
    [pscustomobject]@{
        Present        = $true
        Fingerprint    = Get-TextFingerprint -Value $seed
        InterfaceIndex = $route.InterfaceIndex
        Status         = [string]$adapter.Status
    }
}

function Get-TunEvidence {
    param([string]$DeviceName)
    $adapter = Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $DeviceName -and $_.InterfaceDescription -eq 'Meta Tunnel' } |
        Select-Object -First 1
    [pscustomobject]@{
        Present        = $null -ne $adapter
        Status         = $(if ($null -ne $adapter) { [string]$adapter.Status } else { $null })
        InterfaceIndex = $(if ($null -ne $adapter) { $adapter.InterfaceIndex } else { $null })
        Description    = $(if ($null -ne $adapter) { [string]$adapter.InterfaceDescription } else { $null })
    }
}

function Get-EnvironmentEvidence {
    $os = Get-CimInstance Win32_OperatingSystem
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    [pscustomobject]@{
        Caption         = [string]$os.Caption
        Version         = [string]$os.Version
        BuildNumber     = [string]$os.BuildNumber
        Architecture    = [string]$os.OSArchitecture
        BootTimeUtc     = ConvertTo-UtcText -Value $os.LastBootUpTime
        Elevated        = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        PowerShell      = $PSVersionTable.PSVersion.ToString()
    }
}

function Get-Snapshot {
    param([datetime]$SessionStart, [string]$DeviceName)
    $os = Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{
        CapturedAtUtc = ConvertTo-UtcText -Value (Get-Date)
        BootTimeUtc   = ConvertTo-UtcText -Value $os.LastBootUpTime
        Installed     = Get-InstalledEvidence
        Processes     = [pscustomobject]@{
            ClashXY = Get-ProcessEvidence -Pattern '^ClashXY$'
            Mihomo  = Get-ProcessEvidence -Pattern 'mihomo'
        }
        Tun            = Get-TunEvidence -DeviceName $DeviceName
        DefaultNetwork = Get-NetworkEvidence
        ResumeEvents   = @(
            Get-SystemEvents -LogName 'System' -Ids @(1) -StartTime $SessionStart -ProviderName 'Microsoft-Windows-Power-Troubleshooter'
            Get-SystemEvents -LogName 'System' -Ids @(107) -StartTime $SessionStart -ProviderName 'Microsoft-Windows-Kernel-Power'
        )
        NetworkEvents  = @(Get-SystemEvents -LogName 'Microsoft-Windows-NetworkProfile/Operational' -Ids @(10000, 10001) -StartTime $SessionStart -ProviderName '')
    }
}

function Get-StatePath {
    param([string]$Directory)
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        throw '-EvidenceDirectory is required for Record, Status, and Finish.'
    }
    $resolved = [System.IO.Path]::GetFullPath($Directory)
    $path = Join-Path $resolved 'state.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Lifecycle evidence state was not found: $path"
    }
    return $path
}

function Save-State {
    param([object]$State, [string]$Path)
    Write-Utf8File -Path $Path -Content (($State | ConvertTo-Json -Depth 12) + [Environment]::NewLine)
}

function Get-CheckpointRecord {
    param([object]$State, [string]$Name)
    return @($State.Checkpoints | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
}

function Assert-FinalEvidence {
    param([object]$State)
    if (-not $State.ReleaseGateEligible) {
        throw 'This run used an unsigned candidate and is not eligible for the final release gate.'
    }
    if ([string]::IsNullOrWhiteSpace($State.ExpectedPublisherPattern) -or
        $State.Installer.Signature.Publisher -notmatch $State.ExpectedPublisherPattern) {
        throw 'P6-010 final evidence requires an explicit matching Authenticode publisher pattern.'
    }
    if ($State.Environment.Architecture -notmatch '64') {
        throw 'P6-010 requires Windows x64.'
    }
    if ($State.Environment.Caption -notmatch 'Windows (10|11)') {
        throw "Unsupported P6-010 operating system: $($State.Environment.Caption)"
    }
    if ([string]::IsNullOrWhiteSpace($State.SourceCommit) -or $State.SourceCommit -notmatch '^[0-9a-f]{40}$') {
        throw 'P6-010 evidence must be collected from a Git checkout with an exact source commit.'
    }
    foreach ($name in $requiredCheckpoints) {
        $record = Get-CheckpointRecord -State $State -Name $name
        if ($null -eq $record -or $record.Result -ne 'Pass') {
            throw "Required checkpoint is missing or did not pass: $name"
        }
    }

    $install = Get-CheckpointRecord -State $State -Name 'install'
    if (-not $install.Snapshot.Installed.Present) {
        throw 'The install checkpoint does not show an installed ClashXY package.'
    }
    foreach ($file in @($install.Snapshot.Installed.Executable, $install.Snapshot.Installed.Uninstaller)) {
        if ($null -eq $file -or $file.Signature.Status -ne 'Valid' -or -not $file.Signature.Timestamped) {
            throw 'The installed executable and uninstaller must both have valid timestamped Authenticode signatures.'
        }
        if (-not [string]::IsNullOrWhiteSpace($State.ExpectedPublisherPattern) -and
            $file.Signature.Publisher -notmatch $State.ExpectedPublisherPattern) {
            throw "Installed file publisher does not match the expected pattern: $($file.Name)"
        }
        if ($file.Signature.Publisher -ne $State.Installer.Signature.Publisher) {
            throw "Installed file publisher differs from the installer publisher: $($file.Name)"
        }
    }
    if ($install.Snapshot.Installed.Executable.ProductVersion -ne $State.ExpectedVersion) {
        throw 'Installed ClashXY.exe product version does not match the expected release version.'
    }

    $baseline = Get-CheckpointRecord -State $State -Name 'clean-machine-baseline'
    if ($baseline.Snapshot.Installed.Present -or $baseline.Snapshot.Processes.ClashXY.Count -gt 0 -or
        $baseline.Snapshot.Processes.Mihomo.Count -gt 0 -or $baseline.Snapshot.Tun.Present) {
        throw 'Clean-machine baseline still shows an installation, ClashXY/Mihomo process, or owned TUN adapter.'
    }

    foreach ($name in @('subscription-connect', 'node-switch', 'internet-access', 'profile-switch', 'app-restart-restore', 'sleep-resume', 'network-switch-recovery', 'system-restart-autoconnect')) {
        $snapshot = (Get-CheckpointRecord -State $State -Name $name).Snapshot
        if (-not $snapshot.Tun.Present -or $snapshot.Tun.Status -ne 'Up' -or $snapshot.Processes.Mihomo.Count -lt 1) {
            throw "Connected checkpoint lacks a running Mihomo process and an Up TUN adapter: $name"
        }
        if ($snapshot.Processes.ClashXY.Count -lt 1) {
            throw "Connected checkpoint lacks a running ClashXY process: $name"
        }
    }

    $appBefore = Get-CheckpointRecord -State $State -Name 'app-before-restart'
    $appAfter = Get-CheckpointRecord -State $State -Name 'app-restart-restore'
    if ([string]::IsNullOrWhiteSpace($appBefore.Snapshot.Processes.ClashXY.LatestStartTimeUtc) -or
        $appBefore.Snapshot.Processes.ClashXY.LatestStartTimeUtc -eq $appAfter.Snapshot.Processes.ClashXY.LatestStartTimeUtc) {
        throw 'Application restart evidence does not show a new ClashXY process start time.'
    }

    $sleepBefore = Get-CheckpointRecord -State $State -Name 'sleep-before'
    $resumeEvents = @((Get-CheckpointRecord -State $State -Name 'sleep-resume').Snapshot.ResumeEvents |
        Where-Object { [datetime]$_.TimeCreatedUtc -gt [datetime]$sleepBefore.RecordedAtUtc })
    if ($resumeEvents.Count -lt 1) {
        throw 'Sleep/resume evidence does not include a Windows resume event after the pre-sleep checkpoint.'
    }

    $networkBefore = Get-CheckpointRecord -State $State -Name 'network-before-switch'
    $networkAfter = Get-CheckpointRecord -State $State -Name 'network-switch-recovery'
    $networkEvents = @($networkAfter.Snapshot.NetworkEvents |
        Where-Object { [datetime]$_.TimeCreatedUtc -gt [datetime]$networkBefore.RecordedAtUtc })
    if ($networkEvents.Count -lt 1 -and
        $networkBefore.Snapshot.DefaultNetwork.Fingerprint -eq $networkAfter.Snapshot.DefaultNetwork.Fingerprint) {
        throw 'Network-switch evidence shows neither a network-profile event nor a changed default-network fingerprint.'
    }

    $systemBefore = Get-CheckpointRecord -State $State -Name 'system-before-restart'
    $systemAfter = Get-CheckpointRecord -State $State -Name 'system-restart-autoconnect'
    if ([datetime]$systemAfter.Snapshot.BootTimeUtc -le [datetime]$systemBefore.Snapshot.BootTimeUtc) {
        throw 'System restart evidence does not show a later Windows boot time.'
    }

    $disconnect = Get-CheckpointRecord -State $State -Name 'disconnect-cleanup'
    if ($disconnect.Snapshot.Tun.Present -or $disconnect.Snapshot.Processes.Mihomo.Count -gt 0) {
        throw 'Disconnect cleanup evidence still shows Mihomo or the ClashXY TUN adapter.'
    }
    $uninstall = Get-CheckpointRecord -State $State -Name 'uninstall-cleanup'
    if ($uninstall.Snapshot.Installed.Present -or $uninstall.Snapshot.Processes.ClashXY.Count -gt 0 -or
        $uninstall.Snapshot.Processes.Mihomo.Count -gt 0 -or $uninstall.Snapshot.Tun.Present) {
        throw 'Uninstall cleanup evidence still shows installed files, processes, or the ClashXY TUN adapter.'
    }
}

if ($Action -eq 'Start') {
    if ([string]::IsNullOrWhiteSpace($InstallerPath) -or [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
        throw 'Start requires -InstallerPath and -ExpectedVersion.'
    }
    if ($ExpectedVersion -notmatch '^\d+\.\d+\.\d+\+\d+$' -and -not $AllowUnsignedCandidate) {
        throw '-ExpectedVersion must use the application version format <major>.<minor>.<patch>+<build>.'
    }
    if ($TunDeviceName -notmatch '^[A-Za-z0-9][A-Za-z0-9._ -]{0,63}$') {
        throw '-TunDeviceName contains unsupported characters or is too long.'
    }
    $installer = [System.IO.Path]::GetFullPath($InstallerPath)
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
        throw "Installer was not found: $installer"
    }
    if (-not $AllowUnsignedCandidate -and [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
        throw 'A final P6-010 run requires -ExpectedPublisherPattern.'
    }
    $environment = Get-EnvironmentEvidence
    if (-not $environment.Elevated) {
        throw 'P6-010 evidence collection requires an elevated PowerShell session.'
    }
    $installerEvidence = Get-FileEvidence -Path $installer
    $eligible = $installerEvidence.Signature.Status -eq 'Valid' -and $installerEvidence.Signature.Timestamped
    if (-not $AllowUnsignedCandidate) {
        $verifyArguments = @{ Path = @($installer); SkipSignTool = $true }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
            $verifyArguments.ExpectedPublisherPattern = $ExpectedPublisherPattern
        }
        & (Join-Path $PSScriptRoot 'verify_windows_signatures.ps1') @verifyArguments | Out-Host
        $eligible = $true
    }
    if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
        $EvidenceDirectory = Join-Path $repository ("build\p6-010\{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    $directory = [System.IO.Path]::GetFullPath($EvidenceDirectory)
    if (Test-Path -LiteralPath $directory) {
        if (@(Get-ChildItem -LiteralPath $directory -Force).Count -gt 0) {
            throw "Evidence directory is not empty: $directory"
        }
    } else {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $started = Get-Date
    $commit = $null
    try {
        $commit = (& git -C $repository rev-parse HEAD 2>$null).Trim()
    } catch { }
    if ([string]::IsNullOrWhiteSpace($commit) -or $commit -notmatch '^[0-9a-f]{40}$') {
        throw 'Unable to resolve the exact Git source commit for this P6-010 run.'
    }
    $state = [pscustomobject]@{
        SchemaVersion            = 1
        RunId                    = [guid]::NewGuid().ToString('N')
        StartedAtUtc             = ConvertTo-UtcText -Value $started
        CompletedAtUtc           = $null
        SourceCommit             = $commit
        ExpectedVersion          = $ExpectedVersion
        ExpectedPublisherPattern = $ExpectedPublisherPattern
        TunDeviceName            = $TunDeviceName
        ReleaseGateEligible      = $eligible
        Environment              = $environment
        Installer                = $installerEvidence
        InitialSnapshot          = Get-Snapshot -SessionStart $started -DeviceName $TunDeviceName
        FinalSnapshot            = $null
        RequiredCheckpoints      = $requiredCheckpoints
        Checkpoints              = @()
    }
    $statePath = Join-Path $directory 'state.json'
    Save-State -State $state -Path $statePath
    [pscustomobject]@{
        EvidenceDirectory   = $directory
        RunId               = $state.RunId
        OperatingSystem     = $environment.Caption
        InstallerSHA256     = $installerEvidence.SHA256
        ReleaseGateEligible = $eligible
    }
    return
}

$statePath = Get-StatePath -Directory $EvidenceDirectory
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$sessionStart = [datetime]$state.StartedAtUtc

if ($Action -eq 'Record') {
    if ([string]::IsNullOrWhiteSpace($Checkpoint) -or [string]::IsNullOrWhiteSpace($Result)) {
        throw 'Record requires -Checkpoint and -Result.'
    }
    if ($requiredCheckpoints -notcontains $Checkpoint -and $optionalCheckpoints -notcontains $Checkpoint) {
        throw "Unknown checkpoint '$Checkpoint'. Run Status to list valid checkpoints."
    }
    $record = [pscustomobject]@{
        Name          = $Checkpoint
        Result        = $Result
        RecordedAtUtc = ConvertTo-UtcText -Value (Get-Date)
        Notes         = Protect-EvidenceText -Value $Notes
        Snapshot      = Get-Snapshot -SessionStart $sessionStart -DeviceName $state.TunDeviceName
    }
    $state.Checkpoints = @($state.Checkpoints | Where-Object { $_.Name -ne $Checkpoint }) + @($record)
    $state.Checkpoints = @($state.Checkpoints | Sort-Object RecordedAtUtc)
    Save-State -State $state -Path $statePath
    $record
    return
}

if ($Action -eq 'Status') {
    $rows = foreach ($name in $requiredCheckpoints) {
        $record = Get-CheckpointRecord -State $state -Name $name
        [pscustomobject]@{
            Checkpoint = $name
            Result     = $(if ($null -ne $record) { $record.Result } else { 'Pending' })
            RecordedAt = $(if ($null -ne $record) { $record.RecordedAtUtc } else { $null })
        }
    }
    $rows
    return
}

Assert-FinalEvidence -State $state
$state.CompletedAtUtc = ConvertTo-UtcText -Value (Get-Date)
$state.FinalSnapshot = Get-Snapshot -SessionStart $sessionStart -DeviceName $state.TunDeviceName
Save-State -State $state -Path $statePath

$reportPath = Join-Path (Split-Path $statePath -Parent) 'report.md'
$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# ClashXY P6-010 Windows lifecycle evidence')
$report.Add('')
$report.Add("- Run ID: ``$($state.RunId)``")
$report.Add("- OS: $($state.Environment.Caption) $($state.Environment.Version) (build $($state.Environment.BuildNumber), $($state.Environment.Architecture))")
$report.Add("- Source commit: ``$($state.SourceCommit)``")
$report.Add("- Expected version: ``$($state.ExpectedVersion)``")
$report.Add("- Installer: ``$($state.Installer.Name)``")
$report.Add("- Installer SHA-256: ``$($state.Installer.SHA256)``")
$report.Add("- Authenticode publisher: $($state.Installer.Signature.Publisher)")
$report.Add("- Started (UTC): $($state.StartedAtUtc)")
$report.Add("- Completed (UTC): $($state.CompletedAtUtc)")
$report.Add('')
$report.Add('| Checkpoint | Result | Recorded (UTC) | Notes |')
$report.Add('| --- | --- | --- | --- |')
foreach ($record in @($state.Checkpoints | Sort-Object RecordedAtUtc)) {
    $safeNotes = [string]$record.Notes
    $safeNotes = $safeNotes.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
    $report.Add("| ``$($record.Name)`` | $($record.Result) | $($record.RecordedAtUtc) | $safeNotes |")
}
Write-Utf8File -Path $reportPath -Content (($report -join [Environment]::NewLine) + [Environment]::NewLine)

$manifestPath = Join-Path (Split-Path $statePath -Parent) 'evidence.sha256'
$manifest = @(
    "$(Get-FileHash -LiteralPath $statePath -Algorithm SHA256 | Select-Object -ExpandProperty Hash) *state.json",
    "$(Get-FileHash -LiteralPath $reportPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash) *report.md"
)
Write-Utf8File -Path $manifestPath -Content (($manifest -join [Environment]::NewLine) + [Environment]::NewLine)

[pscustomobject]@{
    EvidenceDirectory = Split-Path $statePath -Parent
    State              = $statePath
    Report             = $reportPath
    Manifest           = $manifestPath
    Completed          = $true
}
