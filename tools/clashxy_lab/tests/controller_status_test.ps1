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
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('clashxy-controller-test-' + [guid]::NewGuid().ToString('N'))
$runtimeDirectory = Join-Path $testRoot 'runtime'
$configPath = Join-Path $testRoot 'config.yaml'
$statePath = Join-Path $runtimeDirectory 'mihomo-process.json'
$startedPid = $null
$uuidPlain = '0c5849d0-4f40-4f83-9fdc-ec5b5fcac606'
$controllerPlain = 'fixture-controller-health-secret-32'
$wrongControllerPlain = 'fixture-controller-wrong-secret'

try {
    [void][System.IO.Directory]::CreateDirectory($runtimeDirectory)
    $mixedPort = Get-FreeTcpPort
    do {
        $controllerPort = Get-FreeTcpPort
    } while ($controllerPort -eq $mixedPort)
    $controllerUri = [uri]('http://127.0.0.1:' + $controllerPort)

    $profile = [pscustomobject][ordered]@{
        PSTypeName          = 'ClashXY.ProxyProfile'
        Protocol            = 'vless'
        SensitiveFieldNames = @('uuid')
        Fields              = [ordered]@{
            name                 = 'fixture-controller-vless'
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

    $document = & (Join-Path $labRoot 'build_mihomo_config.ps1') -ProxyProfiles @($profile) -ControllerSecret (ConvertTo-TestSecureString $controllerPlain) -MixedPort $mixedPort -ControllerPort $controllerPort
    $null = & (Join-Path $labRoot 'write_mihomo_config.ps1') -ConfigDocument $document -OutputPath $configPath

    $startResult = (@(& $cliPath mihomo start -CorePath $CorePath -ConfigPath $configPath -RuntimeDirectory $runtimeDirectory -StatePath $statePath) -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
    if (-not $startResult.Started) {
        throw 'Failed to start Mihomo for controller test.'
    }
    $startedPid = [int]$startResult.Pid

    $statusText = @(& $cliPath status -ControllerUri $controllerUri -ControllerSecret (ConvertTo-TestSecureString $controllerPlain) -ControllerTimeoutSeconds 5) -join [Environment]::NewLine
    $statusResult = $statusText | ConvertFrom-Json -ErrorAction Stop
    if (-not $statusResult.Healthy -or $statusResult.StatusCode -ne 200 -or -not $statusResult.Meta -or [string]::IsNullOrWhiteSpace($statusResult.Version)) {
        throw 'Controller status response was not healthy.'
    }

    $wrongSecretError = $null
    try {
        & $cliPath status -ControllerUri $controllerUri -ControllerSecret (ConvertTo-TestSecureString $wrongControllerPlain) -ControllerTimeoutSeconds 5 | Out-Null
    }
    catch {
        $wrongSecretError = $_.Exception.Message
    }
    if ([string]::IsNullOrWhiteSpace($wrongSecretError) -or $wrongSecretError -notmatch 'HTTP status 401') {
        throw 'Controller status did not reject the wrong secret with HTTP 401.'
    }

    $remoteHttpError = $null
    try {
        & (Join-Path $labRoot 'controller_status.ps1') -ControllerUri ([uri]'http://192.0.2.1:9090') -ControllerSecret (ConvertTo-TestSecureString $controllerPlain) | Out-Null
    }
    catch {
        $remoteHttpError = $_.Exception.Message
    }
    if ([string]::IsNullOrWhiteSpace($remoteHttpError) -or $remoteHttpError -notmatch 'loopback') {
        throw 'Controller status did not reject remote plain HTTP before the request.'
    }

    $observableText = $statusText + $wrongSecretError + $remoteHttpError
    foreach ($secretValue in @($uuidPlain, $controllerPlain, $wrongControllerPlain)) {
        if ($observableText.Contains($secretValue, [System.StringComparison]::Ordinal)) {
            throw 'Controller status output leaked a fixture secret.'
        }
    }

    $stopResult = (@(& $cliPath mihomo stop -RuntimeDirectory $runtimeDirectory -StatePath $statePath) -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
    if (-not $stopResult.Stopped -or $stopResult.Pid -ne $startedPid) {
        throw 'Failed to stop Mihomo after controller test.'
    }
    $startedPid = $null

    'PASS: authenticated Mihomo /version health, wrong-secret rejection, loopback HTTP guard, redaction, and cleanup'
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
            -not [System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('clashxy-controller-test-', [System.StringComparison]::Ordinal)) {
            throw 'Refusing to remove an unexpected controller test directory.'
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
