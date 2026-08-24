[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CorePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-TestSecureString {
    param([Parameter(Mandatory)][string]$Value)
    return ConvertTo-SecureString -String $Value -AsPlainText -Force
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

$labRoot = Split-Path $PSScriptRoot -Parent
$cliPath = Join-Path $labRoot 'clashxy_lab.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('clashxy-process-test-' + [guid]::NewGuid().ToString('N'))
$runtimeDirectory = Join-Path $testRoot 'runtime'
$configPath = Join-Path $testRoot 'config.yaml'
$statePath = Join-Path $runtimeDirectory 'mihomo-process.json'
$startedPid = $null
$uuidPlain = '0c5849d0-4f40-4f83-9fdc-ec5b5fcac606'
$hy2PasswordPlain = 'fixture-hy2-password'
$controllerPlain = 'fixture-controller-secret-32-bytes'

try {
    [void][System.IO.Directory]::CreateDirectory($runtimeDirectory)
    $mixedPort = Get-FreeTcpPort
    do {
        $controllerPort = Get-FreeTcpPort
    } while ($controllerPort -eq $mixedPort)

    $vlessProfile = [pscustomobject][ordered]@{
        PSTypeName          = 'ClashXY.ProxyProfile'
        Protocol            = 'vless'
        SensitiveFieldNames = @('uuid')
        Fields              = [ordered]@{
            name                 = 'fixture-vless'
            type                 = 'vless'
            server               = 'example.com'
            port                 = 443
            uuid                 = ConvertTo-TestSecureString $uuidPlain
            udp                  = $true
            tls                  = $true
            servername           = 'www.microsoft.com'
            'skip-cert-verify'   = $false
            encryption           = ''
            flow                 = 'xtls-rprx-vision'
            'client-fingerprint' = 'chrome'
            network              = 'tcp'
            'reality-opts'       = [ordered]@{
                'public-key' = 'KAFmF3QKLoP7hAfWQiBX0niiZw3FLKJ5AGborsv_bkw'
                'short-id'   = 'a1b2c3d4'
            }
        }
    }
    $hy2Profile = [pscustomobject][ordered]@{
        PSTypeName          = 'ClashXY.ProxyProfile'
        Protocol            = 'hysteria2'
        SensitiveFieldNames = @('password')
        Fields              = [ordered]@{
            name               = 'fixture-hy2'
            type               = 'hysteria2'
            server             = 'example.com'
            port               = 443
            password           = ConvertTo-TestSecureString $hy2PasswordPlain
            sni                = 'example.com'
            'skip-cert-verify' = $true
            up                 = '10 Mbps'
            down               = '20 Mbps'
        }
    }

    $document = & (Join-Path $labRoot 'build_mihomo_config.ps1') -ProxyProfiles @($vlessProfile, $hy2Profile) -ControllerSecret (ConvertTo-TestSecureString $controllerPlain) -MixedPort $mixedPort -ControllerPort $controllerPort
    $writeResult = & (Join-Path $labRoot 'write_mihomo_config.ps1') -ConfigDocument $document -OutputPath $configPath
    if (-not $writeResult.Written -or $writeResult.ProxyCount -ne 2) {
        throw 'Failed to write the process test config.'
    }

    $startRaw = @(& $cliPath mihomo start -CorePath $CorePath -ConfigPath $configPath -RuntimeDirectory $runtimeDirectory -StatePath $statePath -ProcessTimeoutSeconds 10)
    $startText = $startRaw -join [Environment]::NewLine
    $startResult = $startText | ConvertFrom-Json -ErrorAction Stop
    if (-not $startResult.Started -or $startResult.AlreadyRunning -or $startResult.Pid -le 0) {
        throw 'mihomo start did not report a successful new process.'
    }
    $startedPid = [int]$startResult.Pid
    $running = Get-Process -Id $startedPid -ErrorAction Stop
    if ($running.HasExited -or -not [System.IO.File]::Exists($statePath)) {
        throw 'Mihomo process or state file is missing after start.'
    }

    $stateText = [System.IO.File]::ReadAllText($statePath)

    $stopRaw = @(& $cliPath mihomo stop -RuntimeDirectory $runtimeDirectory -StatePath $statePath -ProcessTimeoutSeconds 10)
    $stopResult = ($stopRaw -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
    if (-not $stopResult.Stopped -or $stopResult.AlreadyStopped -or $stopResult.Pid -ne $startedPid) {
        throw 'mihomo stop did not report the expected process.'
    }
    $startedPid = $null
    if ([System.IO.File]::Exists($statePath)) {
        throw 'Mihomo process state was not removed after stop.'
    }
    if ($null -ne (Get-Process -Id ([int]$stopResult.Pid) -ErrorAction SilentlyContinue)) {
        throw 'Mihomo process remains alive after stop.'
    }

    $stdoutPath = Join-Path $runtimeDirectory 'mihomo.stdout.log'
    $stderrPath = Join-Path $runtimeDirectory 'mihomo.stderr.log'
    $stdoutText = if ([System.IO.File]::Exists($stdoutPath)) { [System.IO.File]::ReadAllText($stdoutPath) } else { '' }
    $stderrText = if ([System.IO.File]::Exists($stderrPath)) { [System.IO.File]::ReadAllText($stderrPath) } else { '' }
    $stopText = $stopRaw -join [Environment]::NewLine
    $observableText = $startText + $stopText + $stateText + $stdoutText + $stderrText
    foreach ($secretValue in @($uuidPlain, $hy2PasswordPlain, $controllerPlain)) {
        if ($observableText.Contains($secretValue, [System.StringComparison]::Ordinal)) {
            throw 'Mihomo process output, state, or logs leaked a fixture secret.'
        }
    }

    'PASS: official Mihomo config validation, hidden Windows start, PID identity state, redacted logs, and stop'
}
finally {
    if ($null -ne $startedPid) {
        $candidate = Get-Process -Id $startedPid -ErrorAction SilentlyContinue
        if ($null -ne $candidate -and [System.IO.Path]::GetFullPath($candidate.Path).Equals([System.IO.Path]::GetFullPath($CorePath), [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-Process -Id $startedPid -Force -ErrorAction SilentlyContinue
        }
    }
    if ([System.IO.Directory]::Exists($testRoot)) {
        $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolvedTestRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not [System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('clashxy-process-test-', [System.StringComparison]::Ordinal)) {
            throw 'Refusing to remove an unexpected process test directory.'
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
