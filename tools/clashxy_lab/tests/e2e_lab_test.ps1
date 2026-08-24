[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CorePath
)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'ClashXY E2E requires PowerShell 7 or newer. Re-run with: pwsh -NoProfile -File .\tests\e2e_lab_test.ps1 -CorePath <path-to-mihomo.exe>'
}


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
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('clashxy-e2e-test-' + [guid]::NewGuid().ToString('N'))
$serverRuntime = Join-Path $testRoot 'server-runtime'
$clientRuntime = Join-Path $testRoot 'client-runtime'
$serverConfigPath = Join-Path $serverRuntime 'server.yaml'
$serverStatePath = Join-Path $serverRuntime 'mihomo-process.json'
$mockPort = Get-FreeTcpPort
$mockStdout = Join-Path $testRoot 'mock.stdout'
$mockStderr = Join-Path $testRoot 'mock.stderr'
$nodePath = (Get-Command node -ErrorAction Stop).Source
$mockScript = Join-Path $PSScriptRoot 'mock-2sui-server.mjs'
$mockProcess = $null
$serverStarted = $false
$baselineMihomo = @(Get-NetAdapter -Name 'Mihomo' -ErrorAction SilentlyContinue | Select-Object Name, ifIndex)
$uuidPlain = [guid]::NewGuid().ToString()
$uuidSecure = ConvertTo-TestSecureString $uuidPlain
$shortIdBytes = [byte[]]::new(8)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($shortIdBytes)
$shortId = [Convert]::ToHexString($shortIdBytes).ToLowerInvariant()
[Array]::Clear($shortIdBytes, 0, $shortIdBytes.Length)
$serverName = 'www.microsoft.com'
$nonce = 'clashxy-e2e-' + [guid]::NewGuid().ToString('N')
$serverControllerPlain = 'fixture-e2e-server-controller-secret'
$realityPrivatePlain = $null
$realityPublic = $null

try {
    [void][System.IO.Directory]::CreateDirectory($serverRuntime)
    [void][System.IO.Directory]::CreateDirectory($clientRuntime)

    $keyOutput = @(& $CorePath generate reality-keypair 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw 'Official Mihomo failed to generate an E2E Reality keypair.'
    }
    $keyText = $keyOutput -join [Environment]::NewLine
    $realityPrivatePlain = [regex]::Match($keyText, '(?im)^PrivateKey:\s*(\S+)').Groups[1].Value
    $realityPublic = [regex]::Match($keyText, '(?im)^PublicKey:\s*(\S+)').Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($realityPrivatePlain) -or [string]::IsNullOrWhiteSpace($realityPublic)) {
        throw 'Unexpected Reality keypair output.'
    }

    $vlessPort = Get-FreeTcpPort
    do {
        $serverMixedPort = Get-FreeTcpPort
    } while ($serverMixedPort -eq $vlessPort)
    do {
        $serverControllerPort = Get-FreeTcpPort
    } while ($serverControllerPort -in @($vlessPort, $serverMixedPort))

    $serverAst = [ordered]@{
        'mixed-port'          = $serverMixedPort
        'allow-lan'           = $false
        mode                  = 'rule'
        'log-level'           = 'info'
        ipv6                  = $false
        'external-controller' = '127.0.0.1:' + $serverControllerPort
        secret                = ConvertTo-TestSecureString $serverControllerPlain
        hosts                 = [ordered]@{
            'clashxy-e2e.test' = '127.0.0.1'
        }
        listeners             = @(
            [ordered]@{
                name             = 'clashxy-e2e-vless-in'
                type             = 'vless'
                port             = $vlessPort
                listen           = '127.0.0.1'
                users            = @(
                    [ordered]@{
                        username = 'clashxy-e2e-user'
                        uuid     = $uuidSecure
                        flow     = 'xtls-rprx-vision'
                    }
                )
                'reality-config' = [ordered]@{
                    dest           = $serverName + ':443'
                    'private-key'  = ConvertTo-TestSecureString $realityPrivatePlain
                    'short-id'     = @($shortId)
                    'server-names' = @($serverName)
                }
            }
        )
        rules                 = @('MATCH,DIRECT')
    }
    $serverDocument = [pscustomobject][ordered]@{
        PSTypeName = 'ClashXY.ConnectionProfile'
        Ast        = $serverAst
        ProxyCount = 0
    }
    $null = & (Join-Path $labRoot 'write_mihomo_config.ps1') -ConfigDocument $serverDocument -OutputPath $serverConfigPath
    $serverStart = & (Join-Path $labRoot 'mihomo_start.ps1') -CorePath $CorePath -ConfigPath $serverConfigPath -RuntimeDirectory $serverRuntime -StatePath $serverStatePath
    if (-not $serverStart.Started) {
        throw 'Local VLESS Reality server did not start.'
    }
    $serverStarted = $true

    $mockEnvironment = @{
        MYMIHOMO_E2E_VLESS_PORT        = [string]$vlessPort
        MYMIHOMO_E2E_REALITY_PUBLIC_KEY = $realityPublic
        MYMIHOMO_E2E_REALITY_SHORT_ID   = $shortId
        MYMIHOMO_E2E_SERVER_NAME        = $serverName
        MYMIHOMO_E2E_NONCE              = $nonce
        MYMIHOMO_MOCK_PORT               = [string]$mockPort
    }
    $mockProcess = Start-Process -FilePath $nodePath -ArgumentList @($mockScript) -Environment $mockEnvironment -WindowStyle Hidden -RedirectStandardOutput $mockStdout -RedirectStandardError $mockStderr -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        if ($mockProcess.HasExited) {
            $detail = if ([System.IO.File]::Exists($mockStderr)) { [System.IO.File]::ReadAllText($mockStderr) } else { '' }
            throw ('E2E mock exited before startup. ' + $detail)
        }
        if ([System.IO.File]::Exists($mockStdout) -and (Get-Item -LiteralPath $mockStdout).Length -gt 0) {
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not [System.IO.File]::Exists($mockStdout) -or (Get-Item -LiteralPath $mockStdout).Length -eq 0) {
        throw 'Timed out waiting for E2E mock.'
    }
    $panelBase = [uri]('http://127.0.0.1:' + $mockPort + '/app/')
    $connectivityUri = [uri]('http://clashxy-e2e.test:' + $mockPort + '/e2e-target')

    $e2eResult = & (Join-Path $labRoot 'e2e_lab.ps1') -CorePath $CorePath -BaseUrl $panelBase -Username 'fixture-user' -Password (ConvertTo-TestSecureString 'fixture-password') -TwoFactorCode (ConvertTo-TestSecureString '123456') -InboundId 7 -ConnectivityUri $connectivityUri -RuntimeDirectory $clientRuntime -VlessUuid $uuidSecure -ExpectedResponseText $nonce -AllowInsecureHttp
    if (-not $e2eResult.Success -or -not $e2eResult.LoginSucceeded -or -not $e2eResult.TokenValidated -or -not $e2eResult.InboundRead -or -not $e2eResult.ClientCreated -or -not $e2eResult.ProfileBuilt -or -not $e2eResult.ControllerHealthy -or -not $e2eResult.TunHealthy -or -not $e2eResult.ConnectivitySucceeded) {
        throw 'E2E orchestrator did not report every required stage successful.'
    }
    if (-not $e2eResult.ClientDeleted -or -not $e2eResult.TokenDeleted -or -not $e2eResult.LogoutSucceeded -or -not $e2eResult.ConfigDeleted) {
        throw 'E2E orchestrator cleanup was incomplete.'
    }

    $clientsResponse = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'apiv2/clients')) -Method Get -Headers @{ Token = 'fixture-token' }
    if (@($clientsResponse.obj.clients | Where-Object { [string]$_.name -like 'clashxy-lab-e2e-windows-*' }).Count -ne 0) {
        throw 'E2E mock retained a created Client after cleanup.'
    }
    if ([System.IO.File]::Exists((Join-Path $clientRuntime 'mihomo-process.json')) -or [System.IO.File]::Exists((Join-Path $clientRuntime 'clashxy-e2e.yaml'))) {
        throw 'E2E client runtime retained process state or credential config.'
    }
    if ($null -ne (Get-NetAdapter -Name $e2eResult.TunDeviceName -ErrorAction SilentlyContinue)) {
        throw 'E2E TUN adapter remained after cleanup.'
    }
    foreach ($baseline in $baselineMihomo) {
        $current = Get-NetAdapter -Name $baseline.Name -ErrorAction SilentlyContinue
        if ($null -eq $current -or [int]$current.ifIndex -ne [int]$baseline.ifIndex) {
            throw 'Pre-existing Mihomo adapter changed during E2E.'
        }
    }
    if ($serverStarted) {
        & (Join-Path $labRoot 'mihomo_stop.ps1') -RuntimeDirectory $serverRuntime -StatePath $serverStatePath | Out-Null
        $serverStarted = $false
    }


    $safeResultJson = $e2eResult | ConvertTo-Json -Depth 10
    $serverStdout = Join-Path $serverRuntime 'mihomo.stdout.log'
    $serverStderr = Join-Path $serverRuntime 'mihomo.stderr.log'
    $observableText = $safeResultJson
    if ([System.IO.File]::Exists($serverStdout)) { $observableText += [System.IO.File]::ReadAllText($serverStdout) }
    if ([System.IO.File]::Exists($serverStderr)) { $observableText += [System.IO.File]::ReadAllText($serverStderr) }
    foreach ($secretValue in @($uuidPlain, $realityPrivatePlain, $serverControllerPlain, 'fixture-password', '123456', 'fixture-generated-token')) {
        if ($observableText.Contains($secretValue, [System.StringComparison]::Ordinal)) {
            throw 'E2E observable output leaked a fixture secret.'
        }
    }

    'PASS: login, short-lived Token, Client create, Reality Profile, official Mihomo server/client, TUN active, proxied HTTP, stop, Client/Token rollback, and redaction'
}
finally {
    if ([System.IO.File]::Exists((Join-Path $clientRuntime 'mihomo-process.json'))) {
        try {
            & (Join-Path $labRoot 'mihomo_stop.ps1') -RuntimeDirectory $clientRuntime -StatePath (Join-Path $clientRuntime 'mihomo-process.json') | Out-Null
        }
        catch {
        }
    }
    if ($serverStarted -or [System.IO.File]::Exists($serverStatePath)) {
        try {
            & (Join-Path $labRoot 'mihomo_stop.ps1') -RuntimeDirectory $serverRuntime -StatePath $serverStatePath | Out-Null
        }
        catch {
        }
    }
    if ($null -ne $mockProcess -and -not $mockProcess.HasExited) {
        Stop-Process -Id $mockProcess.Id -Force -ErrorAction SilentlyContinue
        [void]$mockProcess.WaitForExit(5000)
    }

    $realityPrivatePlain = $null
    $uuidPlain = $null
    if ([System.IO.Directory]::Exists($testRoot)) {
        $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolvedTestRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not [System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('clashxy-e2e-test-', [System.StringComparison]::Ordinal)) {
            throw 'Refusing to remove an unexpected E2E test directory.'
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
