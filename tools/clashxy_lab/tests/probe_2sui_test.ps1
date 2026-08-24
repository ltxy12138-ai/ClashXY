[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testRoot = [System.IO.Path]::GetFullPath(
    (Join-Path ([System.IO.Path]::GetTempPath()) ('clashxy-probe-test-' + [guid]::NewGuid().ToString('N')))
)
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
if (-not $testRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to use a test directory outside the system temp directory.'
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
$stdout = Join-Path $testRoot 'server.stdout'
$stderr = Join-Path $testRoot 'server.stderr'
$serverScript = Join-Path $PSScriptRoot 'mock-2sui-server.mjs'
$labScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'clashxy_lab.ps1'
$nodePath = (Get-Command node -ErrorAction Stop).Source
$panelLoginScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'panel_login.ps1'
$process = $null

try {
    $process = Start-Process `
        -FilePath $nodePath `
        -ArgumentList @($serverScript) `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru

    $deadline = [datetime]::UtcNow.AddSeconds(10)
    do {
        if ($process.HasExited) {
            $detail = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw } else { '' }
            throw "Mock server exited before startup. $detail"
        }
        if ((Test-Path -LiteralPath $stdout) -and (Get-Item -LiteralPath $stdout).Length -gt 0) {
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([datetime]::UtcNow -lt $deadline)

    if (-not (Test-Path -LiteralPath $stdout) -or (Get-Item -LiteralPath $stdout).Length -eq 0) {
        throw 'Timed out waiting for the mock server.'
    }

    $serverInfo = (Get-Content -LiteralPath $stdout -Raw) | ConvertFrom-Json
    $password = ConvertTo-SecureString 'fixture-password' -AsPlainText -Force
    $code = ConvertTo-SecureString '123456' -AsPlainText -Force
    $token = ConvertTo-SecureString 'fixture-token' -AsPlainText -Force

    $json = & $labScript panel-test `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -Username 'fixture-user' `
        -Password $password `
        -TwoFactorCode $code `
        -ApiToken $token `
        -AllowInsecureHttp

    foreach ($forbidden in @('fixture-password', '123456', 'fixture-token', 'fixture-cookie-value')) {
        if ($json -match [regex]::Escape($forbidden)) {
            throw "Probe output leaked fixture secret: $forbidden"
        }
    }

    $result = $json | ConvertFrom-Json -Depth 20
    $stepNames = @($result.Steps.Step)
    foreach ($required in @('login-page', 'apiv2-without-token', 'login', 'login-two-factor', 'session-token-list', 'apiv2-with-token', 'logout')) {
        if ($stepNames -notcontains $required) {
            throw "Missing probe step: $required"
        }
    }

    if (-not ($result.Steps | Where-Object Step -eq 'login-two-factor').Result.Success) {
        throw 'Two-factor login did not succeed.'
    }
    if (-not ($result.Steps | Where-Object Step -eq 'apiv2-with-token').Result.Success) {
        throw 'Token-authenticated API v2 probe did not succeed.'
    }
    if (@($result.CookiesAfterLogin).Name -notcontains 's-ui') {
        throw 'Session cookie metadata was not captured.'
    }

    $twoFactorLogin = & $panelLoginScript `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -Username 'fixture-user' `
        -Password $password `
        -TwoFactorCode $code `
        -AllowInsecureHttp
    if (-not $twoFactorLogin.Success -or -not $twoFactorLogin.TwoFactorUsed) {
        throw 'panel login did not complete the two-factor flow.'
    }
    if (-not $twoFactorLogin.LogoutSuccess -or $twoFactorLogin.SessionCookie.Name -ne 's-ui') {
        throw 'panel login did not capture and clear the session.'
    }

    $noTwoFactorLogin = & $panelLoginScript `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -Username 'fixture-no-2fa-user' `
        -Password $password `
        -AllowInsecureHttp
    if (-not $noTwoFactorLogin.Success -or $noTwoFactorLogin.TwoFactorUsed) {
        throw 'panel login did not complete the no-2FA flow.'
    }

    $badPassword = ConvertTo-SecureString 'fixture-wrong-password' -AsPlainText -Force
    $failedLogin = & $panelLoginScript `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -Username 'fixture-user' `
        -Password $badPassword `
        -TwoFactorCode $code `
        -AllowInsecureHttp
    if ($failedLogin.Success) {
        throw 'panel login accepted an invalid password.'
    }

    $cliJson = & $labScript panel login `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -Username 'fixture-no-2fa-user' `
        -Password $password `
        -AllowInsecureHttp
    $cliLogin = $cliJson | ConvertFrom-Json -Depth 20
    if (-not $cliLogin.Success -or $cliLogin.TwoFactorUsed) {
        throw 'panel login CLI command failed.'
    }

    $loginOutput = @($twoFactorLogin, $noTwoFactorLogin, $failedLogin, $cliLogin) | ConvertTo-Json -Depth 20
    foreach ($forbidden in @('fixture-password', 'fixture-wrong-password', '123456', 'fixture-token', 'fixture-cookie-value')) {
        if ($loginOutput -match [regex]::Escape($forbidden)) {
            throw "Panel login output leaked fixture secret: $forbidden"
        }
    }

    $tokenJson = & $labScript panel token-test `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -Username 'fixture-user' `
        -Password $password `
        -TwoFactorCode $code `
        -TokenExpiryDays 1 `
        -AllowInsecureHttp
    $tokenResult = $tokenJson | ConvertFrom-Json -Depth 20
    if (-not $tokenResult.Success -or -not $tokenResult.ApiV2Success) {
        throw 'panel token-test did not authenticate to API v2.'
    }
    if (-not $tokenResult.TokenDeleted -or -not $tokenResult.TokenAbsentAfterDelete) {
        throw 'panel token-test did not clean up its API Token.'
    }
    if (-not $tokenResult.LogoutSuccess) {
        throw 'panel token-test did not logout.'
    }
    if ($tokenJson -match [regex]::Escape('fixture-generated-token')) {
        throw 'panel token-test output leaked the generated Token.'
    }

    $inboundsJson = & $labScript panel inbounds `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -AllowInsecureHttp
    $inboundsResult = $inboundsJson | ConvertFrom-Json -Depth 20
    if ($inboundsResult.Count -ne 1 -or @($inboundsResult.Inbounds).Count -ne 1) {
        throw 'panel inbounds did not return the fixture Inbound.'
    }
    $inbound = @($inboundsResult.Inbounds)[0]
    if ($inbound.Id -ne 7 -or $inbound.Type -ne 'vless' -or $inbound.Tag -ne 'fixture-vless') {
        throw 'panel inbounds returned an incorrect structural summary.'
    }
    if ($inbound.Listen -ne '::' -or $inbound.Port -ne 443 -or $inbound.TlsId -ne 3 -or $inbound.UserCount -ne 1) {
        throw 'panel inbounds omitted an expected safe summary field.'
    }
    foreach ($forbidden in @('fixture-token', 'fixture-inbound-secret-user', 'fixture-inbound-out-json-secret', 'out_json', '"users"')) {
        if ($inboundsJson -match [regex]::Escape($forbidden)) {
            throw "panel inbounds output leaked a forbidden field or value: $forbidden"
        }
    }

    $clientsJson = & $labScript panel clients `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -AllowInsecureHttp
    $clientsResult = $clientsJson | ConvertFrom-Json -Depth 20
    if ($clientsResult.Count -ne 1 -or @($clientsResult.Clients).Count -ne 1 -or $clientsResult.SnapshotSequence -ne 42) {
        throw 'panel clients did not return the fixture Client snapshot.'
    }
    $client = @($clientsResult.Clients)[0]
    if ($client.Id -ne 11 -or $client.Name -ne 'fixture-client' -or -not $client.Enabled) {
        throw 'panel clients returned an incorrect identity summary.'
    }
    if (@($client.InboundIds).Count -ne 2 -or $client.InboundIds[0] -ne 7 -or $client.InboundIds[1] -ne 9 -or $client.InboundCount -ne 2) {
        throw 'panel clients returned an incorrect Inbound summary.'
    }
    if ($client.Group -ne 'fixture-group' -or $client.UpBytes -ne 11 -or $client.DownBytes -ne 22 -or $client.QuotaBytes -ne 1000 -or $client.ExpiryUnix -ne 2000 -or $client.LimitIp -ne 2) {
        throw 'panel clients omitted an expected safe numeric summary field.'
    }
    foreach ($forbidden in @('fixture-token', 'fixture-client-config-secret', 'fixture-client-link-secret', 'fixture-client-description-secret', 'fixture-client-remark-secret', '"config"', '"links"', '"desc"', '"remark"')) {
        if ($clientsJson -match [regex]::Escape($forbidden)) {
            throw "panel clients output leaked a forbidden field or value: $forbidden"
        }
    }

    $rawInboundEnvelope = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$($serverInfo.port)/app/apiv2/inbounds?id=7" `
        -Method Get `
        -Headers @{ Token = 'fixture-token' }
    $rawClientEnvelope = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$($serverInfo.port)/app/apiv2/clients?id=11" `
        -Method Get `
        -Headers @{ Token = 'fixture-token' }
    $rawInbound = @($rawInboundEnvelope.obj.inbounds)[0]
    $rawClient = @($rawClientEnvelope.obj.clients)[0]
    $vlessModel = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'extract_vless_reality.ps1') -Inbound $rawInbound -Client $rawClient

    if ($vlessModel.Protocol -ne 'vless' -or $vlessModel.InboundId -ne 7 -or $vlessModel.ClientId -ne 11 -or -not $vlessModel.UuidPresent) {
        throw 'VLESS Reality extractor returned an incorrect identity model.'
    }
    $uuidPlain = [System.Net.NetworkCredential]::new('', $vlessModel.Uuid).Password
    try {
        if ($uuidPlain -ne 'fixture-client-config-secret') {
            throw 'VLESS Reality extractor did not preserve the UUID in SecureString form.'
        }
    }
    finally {
        $uuidPlain = $null
    }
    if ($vlessModel.Flow -ne 'xtls-rprx-vision' -or $vlessModel.Transport.Type -ne 'ws' -or $vlessModel.Transport.Path -ne '/fixture-ws') {
        throw 'VLESS Reality extractor returned an incorrect flow or transport.'
    }
    if (@($vlessModel.Transport.Host).Count -ne 1 -or $vlessModel.Transport.Host[0] -ne 'cdn.example.test') {
        throw 'VLESS Reality extractor did not map the WS Host header.'
    }
    if (@($vlessModel.Endpoints).Count -ne 2) {
        throw 'VLESS Reality extractor did not preserve both address endpoints.'
    }
    if ($vlessModel.Endpoints[0].RealityPublicKey -ne 'fixture-reality-public-key' -or $vlessModel.Endpoints[0].RealityShortId -ne 'a1b2c3d4' -or $vlessModel.Endpoints[0].Fingerprint -ne 'chrome') {
        throw 'VLESS Reality extractor did not apply the base TLS client config.'
    }
    if ($vlessModel.Endpoints[1].RealityPublicKey -ne 'fixture-reality-override-public-key' -or $vlessModel.Endpoints[1].ServerName -ne 'alt-sni.example.test' -or $vlessModel.Endpoints[1].Fingerprint -ne 'firefox') {
        throw 'VLESS Reality extractor did not apply the address TLS override.'
    }
    $modelJson = $vlessModel | ConvertTo-Json -Depth 20
    foreach ($forbidden in @('fixture-client-config-secret', 'fixture-reality-private-key-trap', 'fixture-inbound-out-json-secret')) {
        if ($modelJson -match [regex]::Escape($forbidden)) {
            throw "VLESS Reality model serialization leaked a forbidden Secret: $forbidden"
        }
    }

    $unboundClient = ($rawClient | ConvertTo-Json -Depth 100) | ConvertFrom-Json -Depth 100
    $unboundClient.inbounds = @(9)
    $bindingRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'extract_vless_reality.ps1') -Inbound $rawInbound -Client $unboundClient | Out-Null
    }
    catch {
        $bindingRejected = $_.Exception.Message -match 'not bound'
    }
    if (-not $bindingRejected) {
        throw 'VLESS Reality extractor accepted a Client not bound to the Inbound.'
    }

    $vlessSummaryJson = & $labScript profile inspect-vless `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -InboundId 7 `
        -ClientId 11 `
        -AllowInsecureHttp
    $vlessSummary = $vlessSummaryJson | ConvertFrom-Json -Depth 30
    if ($vlessSummary.Protocol -ne 'vless' -or $vlessSummary.EndpointCount -ne 2 -or -not $vlessSummary.UuidPresent) {
        throw 'profile inspect-vless returned an incorrect redacted summary.'
    }
    foreach ($forbidden in @('fixture-token', 'fixture-client-config-secret', 'fixture-reality-public-key', 'fixture-reality-override-public-key', 'fixture-reality-private-key-trap', 'fixture-inbound-out-json-secret')) {
        if ($vlessSummaryJson -match [regex]::Escape($forbidden)) {
            throw "profile inspect-vless output leaked a forbidden value: $forbidden"
        }
    }

    'PASS: VLESS Reality extraction, endpoint overrides, binding guard, SecureString UUID, and redacted summary'

    $vlessProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $vlessModel -EndpointIndex 0 -Name 'fixture-mihomo-vless'
    $vlessFields = $vlessProfile.Fields
    if ($vlessProfile.PSObject.TypeNames -notcontains 'ClashXY.ProxyProfile' -or $vlessProfile.Protocol -ne 'vless' -or $vlessProfile.SourceEndpointIndex -ne 0) {
        throw 'VLESS Mapper returned an incorrect ProxyProfile envelope.'
    }
    if ($vlessFields.name -ne 'fixture-mihomo-vless' -or $vlessFields.type -ne 'vless' -or $vlessFields.server -ne 'edge-one.example.test' -or $vlessFields.port -ne 443) {
        throw 'VLESS Mapper returned incorrect common Mihomo fields.'
    }
    if (-not $vlessFields.udp -or -not $vlessFields.tls -or $vlessFields.flow -ne 'xtls-rprx-vision' -or $vlessFields.encryption -ne '') {
        throw 'VLESS Mapper omitted required VLESS flags or flow.'
    }
    if ($vlessFields.servername -ne 'reality.example.test' -or $vlessFields['client-fingerprint'] -ne 'chrome' -or $vlessFields['skip-cert-verify']) {
        throw 'VLESS Mapper returned incorrect TLS fields.'
    }
    if ($vlessFields['reality-opts']['public-key'] -ne 'fixture-reality-public-key' -or $vlessFields['reality-opts']['short-id'] -ne 'a1b2c3d4') {
        throw 'VLESS Mapper returned incorrect Reality options.'
    }
    if ($vlessFields.network -ne 'ws' -or $vlessFields['ws-opts'].path -ne '/fixture-ws' -or $vlessFields['ws-opts'].headers.Host -ne 'cdn.example.test') {
        throw 'VLESS Mapper returned incorrect WebSocket options.'
    }
    if ($vlessFields['ws-opts']['max-early-data'] -ne 2048 -or $vlessFields['ws-opts']['early-data-header-name'] -ne 'Sec-WebSocket-Protocol') {
        throw 'VLESS Mapper omitted WebSocket Early Data options.'
    }
    if ($vlessFields.uuid -isnot [securestring]) {
        throw 'VLESS Mapper did not preserve UUID as SecureString.'
    }
    $mappedUuidPlain = [System.Net.NetworkCredential]::new('', $vlessFields.uuid).Password
    try {
        if ($mappedUuidPlain -ne 'fixture-client-config-secret') {
            throw 'VLESS Mapper changed the UUID value.'
        }
    }
    finally {
        $mappedUuidPlain = $null
    }
    $vlessProfileJson = $vlessProfile | ConvertTo-Json -Depth 30
    if ($vlessProfileJson -match [regex]::Escape('fixture-client-config-secret')) {
        throw 'VLESS ProxyProfile serialization leaked the UUID.'
    }

    $secondVlessProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $vlessModel -EndpointIndex 1 -Name 'fixture-mihomo-vless-alt'
    if ($secondVlessProfile.Fields.server -ne 'edge-two.example.test' -or $secondVlessProfile.Fields.port -ne 8443 -or $secondVlessProfile.Fields.servername -ne 'alt-sni.example.test') {
        throw 'VLESS Mapper did not select the requested endpoint.'
    }
    if ($secondVlessProfile.Fields['reality-opts']['public-key'] -ne 'fixture-reality-override-public-key' -or $secondVlessProfile.Fields['client-fingerprint'] -ne 'firefox') {
        throw 'VLESS Mapper did not preserve endpoint-specific Reality options.'
    }

    $tcpConnection = $vlessModel | Select-Object *
    $tcpConnection.Transport = [pscustomobject]@{ Type = 'tcp'; Path = ''; Host = @(); Headers = @{}; Method = ''; ServiceName = ''; MaxEarlyData = $null; EarlyDataHeaderName = '' }
    $tcpProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $tcpConnection -Name 'fixture-tcp'
    if ($tcpProfile.Fields.network -ne 'tcp' -or $tcpProfile.Fields.Contains('ws-opts')) {
        throw 'VLESS Mapper returned incorrect TCP transport fields.'
    }

    $httpConnection = $vlessModel | Select-Object *
    $httpConnection.Transport = [pscustomobject]@{ Type = 'http'; Path = '/fixture-http'; Host = @('h1.example.test', 'h2.example.test'); Headers = @{ Connection = @('keep-alive') }; Method = 'POST'; ServiceName = ''; MaxEarlyData = $null; EarlyDataHeaderName = '' }
    $httpProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $httpConnection -Name 'fixture-http'
    if ($httpProfile.Fields.network -ne 'http' -or $httpProfile.Fields['http-opts'].method -ne 'POST' -or $httpProfile.Fields['http-opts'].path[0] -ne '/fixture-http') {
        throw 'VLESS Mapper returned incorrect HTTP transport fields.'
    }
    if (@($httpProfile.Fields['http-opts'].headers.Host).Count -ne 2) {
        throw 'VLESS Mapper did not preserve HTTP Host choices.'
    }

    $grpcConnection = $vlessModel | Select-Object *
    $grpcConnection.Transport = [pscustomobject]@{ Type = 'grpc'; Path = ''; Host = @(); Headers = @{}; Method = ''; ServiceName = 'fixture-grpc'; MaxEarlyData = $null; EarlyDataHeaderName = '' }
    $grpcProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $grpcConnection -Name 'fixture-grpc'
    if ($grpcProfile.Fields.network -ne 'grpc' -or $grpcProfile.Fields['grpc-opts']['grpc-service-name'] -ne 'fixture-grpc') {
        throw 'VLESS Mapper returned incorrect gRPC transport fields.'
    }

    $upgradeConnection = $vlessModel | Select-Object *
    $upgradeConnection.Transport = [pscustomobject]@{ Type = 'httpupgrade'; Path = '/fixture-upgrade'; Host = @('upgrade.example.test'); Headers = @{}; Method = ''; ServiceName = ''; MaxEarlyData = $null; EarlyDataHeaderName = '' }
    $upgradeProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $upgradeConnection -Name 'fixture-upgrade'
    if ($upgradeProfile.Fields.network -ne 'ws' -or -not $upgradeProfile.Fields['ws-opts']['v2ray-http-upgrade'] -or $upgradeProfile.Fields['ws-opts'].path -ne '/fixture-upgrade') {
        throw 'VLESS Mapper did not translate HTTPUpgrade to Mihomo WebSocket upgrade options.'
    }
    if ($upgradeProfile.Fields['ws-opts'].headers.Host -ne 'upgrade.example.test') {
        throw 'VLESS Mapper omitted the HTTPUpgrade Host header.'
    }

    $quicConnection = $vlessModel | Select-Object *
    $quicConnection.Transport = [pscustomobject]@{ Type = 'quic'; Path = ''; Host = @(); Headers = @{}; Method = ''; ServiceName = ''; MaxEarlyData = $null; EarlyDataHeaderName = '' }
    $quicRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_vless_reality_profile.ps1') -Connection $quicConnection -Name 'fixture-quic' | Out-Null
    }
    catch {
        $quicRejected = $_.Exception.Message -match 'unsupported'
    }
    if (-not $quicRejected) {
        throw 'VLESS Mapper accepted an unsupported QUIC transport.'
    }

    'PASS: VLESS Reality to Mihomo ProxyProfile mapping, endpoint selection, supported transports, unsupported transport guard, and UUID redaction'

    $rawHysteriaInboundEnvelope = Invoke-RestMethod -Uri "http://127.0.0.1:$($serverInfo.port)/app/apiv2/inbounds?id=8" -Method Get -Headers @{ Token = 'fixture-token' }
    $rawHysteriaClientEnvelope = Invoke-RestMethod -Uri "http://127.0.0.1:$($serverInfo.port)/app/apiv2/clients?id=12" -Method Get -Headers @{ Token = 'fixture-token' }
    $rawHysteriaInbound = @($rawHysteriaInboundEnvelope.obj.inbounds)[0]
    $rawHysteriaClient = @($rawHysteriaClientEnvelope.obj.clients)[0]
    $hysteriaModel = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'extract_hysteria2.ps1') -Inbound $rawHysteriaInbound -Client $rawHysteriaClient

    if ($hysteriaModel.Protocol -ne 'hysteria2' -or $hysteriaModel.InboundId -ne 8 -or $hysteriaModel.ClientId -ne 12 -or -not $hysteriaModel.PasswordPresent) {
        throw 'Hysteria2 extractor returned an incorrect identity model.'
    }
    $hysteriaPasswordPlain = [System.Net.NetworkCredential]::new('', $hysteriaModel.Password).Password
    $hysteriaObfsPasswordPlain = [System.Net.NetworkCredential]::new('', $hysteriaModel.ObfsPassword).Password
    try {
        if ($hysteriaPasswordPlain -ne 'fixture-hysteria2-client-password') {
            throw 'Hysteria2 extractor did not preserve the Client password in SecureString form.'
        }
        if ($hysteriaObfsPasswordPlain -ne 'fixture-hysteria2-obfs-password') {
            throw 'Hysteria2 extractor did not preserve the obfs password in SecureString form.'
        }
    }
    finally {
        $hysteriaPasswordPlain = $null
        $hysteriaObfsPasswordPlain = $null
    }

    if ($hysteriaModel.ClientUpMbps -ne 200 -or $hysteriaModel.ClientDownMbps -ne 100) {
        throw 'Hysteria2 extractor did not preserve client-view bandwidth values from out_json.'
    }
    if (@($hysteriaModel.ServerPorts).Count -ne 2 -or $hysteriaModel.ServerPorts[0] -ne '20000:20100' -or $hysteriaModel.ServerPorts[1] -ne '30000') {
        throw 'Hysteria2 extractor did not preserve server port ranges.'
    }
    if (-not $hysteriaModel.TcpFastOpen -or $hysteriaModel.ObfsType -ne 'salamander' -or -not $hysteriaModel.ObfsPasswordPresent) {
        throw 'Hysteria2 extractor omitted TCP fast open or obfs metadata.'
    }
    if (@($hysteriaModel.Endpoints).Count -ne 2) {
        throw 'Hysteria2 extractor did not preserve both address endpoints.'
    }
    if ($hysteriaModel.Endpoints[0].ServerName -ne 'hy2-sni.example.test' -or $hysteriaModel.Endpoints[0].Insecure -or $hysteriaModel.Endpoints[0].Fingerprint -ne 'chrome' -or $hysteriaModel.Endpoints[0].CertificatePublicKeySha256Pins[0] -ne 'fixture-hysteria2-base-spki-pin') {
        throw 'Hysteria2 extractor did not apply the base TLS client config.'
    }
    if ($hysteriaModel.Endpoints[1].ServerName -ne 'alt-hy2-sni.example.test' -or -not $hysteriaModel.Endpoints[1].Insecure -or $hysteriaModel.Endpoints[1].Fingerprint -ne 'firefox' -or $hysteriaModel.Endpoints[1].CertificatePublicKeySha256Pins[0] -ne 'fixture-hysteria2-override-spki-pin') {
        throw 'Hysteria2 extractor did not apply the address TLS override.'
    }

    $hysteriaModelJson = $hysteriaModel | ConvertTo-Json -Depth 30
    foreach ($forbidden in @(
        'fixture-hysteria2-client-password',
        'fixture-hysteria2-obfs-password',
        'fixture-hysteria2-tls-private-key-trap',
        'fixture-hysteria2-client-link-trap',
        'fixture-hysteria2-description-trap'
    )) {
        if ($hysteriaModelJson -match [regex]::Escape($forbidden)) {
            throw "Hysteria2 model serialization leaked a forbidden Secret: $forbidden"
        }
    }

    $unboundHysteriaClient = ($rawHysteriaClient | ConvertTo-Json -Depth 100) | ConvertFrom-Json -Depth 100
    $unboundHysteriaClient.inbounds = @(7)
    $hysteriaBindingRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'extract_hysteria2.ps1') -Inbound $rawHysteriaInbound -Client $unboundHysteriaClient | Out-Null
    }
    catch {
        $hysteriaBindingRejected = $_.Exception.Message -match 'not bound'
    }
    if (-not $hysteriaBindingRejected) {
        throw 'Hysteria2 extractor accepted a Client not bound to the Inbound.'
    }

    $realityHysteriaInbound = ($rawHysteriaInbound | ConvertTo-Json -Depth 100) | ConvertFrom-Json -Depth 100
    $realityHysteriaInbound.out_json.tls | Add-Member -NotePropertyName reality -NotePropertyValue ([pscustomobject]@{ enabled = $true }) -Force
    $hysteriaRealityRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'extract_hysteria2.ps1') -Inbound $realityHysteriaInbound -Client $rawHysteriaClient | Out-Null
    }
    catch {
        $hysteriaRealityRejected = $_.Exception.Message -match 'unsupported'
    }
    if (-not $hysteriaRealityRejected) {
        throw 'Hysteria2 extractor accepted a Reality TLS configuration.'
    }

    $hysteriaSummaryJson = & $labScript profile inspect-hysteria2 -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" -ApiToken $token -InboundId 8 -ClientId 12 -AllowInsecureHttp
    $hysteriaSummary = $hysteriaSummaryJson | ConvertFrom-Json -Depth 30
    if ($hysteriaSummary.Protocol -ne 'hysteria2' -or $hysteriaSummary.EndpointCount -ne 2 -or -not $hysteriaSummary.PasswordPresent -or -not $hysteriaSummary.ObfsPasswordPresent -or $hysteriaSummary.ClientUpMbps -ne 200 -or $hysteriaSummary.ClientDownMbps -ne 100) {
        throw 'profile inspect-hysteria2 returned an incorrect redacted summary.'
    }
    if (@($hysteriaSummary.ServerPorts).Count -ne 2 -or $hysteriaSummary.Endpoints[0].CertificatePinCount -ne 1 -or $hysteriaSummary.Endpoints[1].CertificatePinCount -ne 1) {
        throw 'profile inspect-hysteria2 omitted port ranges or certificate pin counts.'
    }
    foreach ($forbidden in @(
        'fixture-token',
        'fixture-hysteria2-client-password',
        'fixture-hysteria2-obfs-password',
        'fixture-hysteria2-base-spki-pin',
        'fixture-hysteria2-override-spki-pin',
        'fixture-hysteria2-tls-private-key-trap',
        'fixture-hysteria2-client-link-trap',
        'fixture-hysteria2-description-trap'
    )) {
        if ($hysteriaSummaryJson -match [regex]::Escape($forbidden)) {
            throw "profile inspect-hysteria2 output leaked a forbidden value: $forbidden"
        }
    }

    'PASS: Hysteria2 extraction, bandwidth direction, endpoint overrides, pin counts, guards, SecureString passwords, and redacted summary'

    $pinGuardRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_hysteria2_profile.ps1') -Connection $hysteriaModel -EndpointIndex 0 -Name 'fixture-hy2-guard' | Out-Null
    }
    catch {
        $pinGuardRejected = $_.Exception.Message -match 'SPKI pins cannot be mapped'
    }
    if (-not $pinGuardRejected) {
        throw 'Hysteria2 Mapper did not reject an unrepresentable SPKI pin by default.'
    }

    $hysteriaProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_hysteria2_profile.ps1') -Connection $hysteriaModel -EndpointIndex 0 -Name 'fixture-mihomo-hy2' -AllowInsecurePinnedCertificate
    $hysteriaFields = $hysteriaProfile.Fields
    if ($hysteriaProfile.PSObject.TypeNames -notcontains 'ClashXY.ProxyProfile' -or $hysteriaProfile.Protocol -ne 'hysteria2' -or $hysteriaProfile.SourceEndpointIndex -ne 0) {
        throw 'Hysteria2 Mapper returned an incorrect ProxyProfile envelope.'
    }
    if ($hysteriaFields.name -ne 'fixture-mihomo-hy2' -or $hysteriaFields.type -ne 'hysteria2' -or $hysteriaFields.server -ne 'hy2-one.example.test' -or $hysteriaFields.port -ne 443) {
        throw 'Hysteria2 Mapper returned incorrect common Mihomo fields.'
    }
    if ($hysteriaFields.ports -ne '20000-20100,30000' -or $hysteriaFields.up -ne '200 Mbps' -or $hysteriaFields.down -ne '100 Mbps') {
        throw 'Hysteria2 Mapper returned incorrect port hopping or bandwidth fields.'
    }
    if ($hysteriaFields.obfs -ne 'salamander' -or $hysteriaFields.password -isnot [securestring] -or $hysteriaFields['obfs-password'] -isnot [securestring]) {
        throw 'Hysteria2 Mapper omitted SecureString password or obfs fields.'
    }
    if ($hysteriaFields.sni -ne 'hy2-sni.example.test' -or @($hysteriaFields.alpn).Count -ne 1 -or $hysteriaFields.alpn[0] -ne 'h3') {
        throw 'Hysteria2 Mapper returned incorrect SNI or ALPN.'
    }
    if (-not $hysteriaFields['skip-cert-verify'] -or $hysteriaProfile.TlsPinMode -ne 'explicit-insecure-pin-downgrade' -or @($hysteriaProfile.SecurityWarnings).Count -ne 1) {
        throw 'Hysteria2 Mapper did not record the explicit SPKI pin security downgrade.'
    }
    if ($hysteriaFields.Contains('fingerprint') -or @($hysteriaProfile.IgnoredSourceFields) -notcontains 'utls.fingerprint') {
        throw 'Hysteria2 Mapper confused a 2S-UI uTLS fingerprint with a Mihomo certificate fingerprint.'
    }

    $mappedHysteriaPasswordPlain = [System.Net.NetworkCredential]::new('', $hysteriaFields.password).Password
    $mappedHysteriaObfsPlain = [System.Net.NetworkCredential]::new('', $hysteriaFields['obfs-password']).Password
    try {
        if ($mappedHysteriaPasswordPlain -ne 'fixture-hysteria2-client-password' -or $mappedHysteriaObfsPlain -ne 'fixture-hysteria2-obfs-password') {
            throw 'Hysteria2 Mapper changed a SecureString credential.'
        }
    }
    finally {
        $mappedHysteriaPasswordPlain = $null
        $mappedHysteriaObfsPlain = $null
    }

    $hysteriaProfileJson = $hysteriaProfile | ConvertTo-Json -Depth 30
    foreach ($forbidden in @(
        'fixture-hysteria2-client-password',
        'fixture-hysteria2-obfs-password',
        'fixture-hysteria2-base-spki-pin',
        'fixture-hysteria2-override-spki-pin',
        'fixture-hysteria2-tls-private-key-trap'
    )) {
        if ($hysteriaProfileJson -match [regex]::Escape($forbidden)) {
            throw "Hysteria2 ProxyProfile serialization leaked a forbidden value: $forbidden"
        }
    }

    $sourceInsecureProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_hysteria2_profile.ps1') -Connection $hysteriaModel -EndpointIndex 1 -Name 'fixture-mihomo-hy2-alt'
    if ($sourceInsecureProfile.Fields.server -ne 'hy2-two.example.test' -or $sourceInsecureProfile.Fields.port -ne 8443 -or -not $sourceInsecureProfile.Fields['skip-cert-verify']) {
        throw 'Hysteria2 Mapper did not select the source-insecure endpoint.'
    }
    if ($sourceInsecureProfile.TlsPinMode -ne 'source-skip-cert-verify' -or @($sourceInsecureProfile.SecurityWarnings).Count -ne 1) {
        throw 'Hysteria2 Mapper did not record the source-insecure SPKI pin condition.'
    }

    $caConnection = $hysteriaModel | Select-Object *
    $caEndpoint = $hysteriaModel.Endpoints[0] | Select-Object *
    $caEndpoint.CertificatePublicKeySha256Pins = @()
    $caConnection.Endpoints = @($caEndpoint)
    $caProfile = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_hysteria2_profile.ps1') -Connection $caConnection -Name 'fixture-mihomo-hy2-ca'
    if ($caProfile.Fields['skip-cert-verify'] -or $caProfile.TlsPinMode -ne 'ca-validation' -or @($caProfile.SecurityWarnings).Count -ne 0) {
        throw 'Hysteria2 Mapper returned an incorrect CA-validation mode.'
    }

    $badPortsConnection = $caConnection | Select-Object *
    $badPortsConnection.ServerPorts = @('40000:30000')
    $badPortRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'map_hysteria2_profile.ps1') -Connection $badPortsConnection -Name 'fixture-hy2-bad-port' | Out-Null
    }
    catch {
        $badPortRejected = $_.Exception.Message -match 'Invalid Hysteria2 server port'
    }
    if (-not $badPortRejected) {
        throw 'Hysteria2 Mapper accepted an invalid descending port range.'
    }

    'PASS: Hysteria2 to Mihomo ProxyProfile mapping, port ranges, bandwidth, SecureString credentials, pin downgrade guard, and fingerprint separation'

    $controllerSecret = ConvertTo-SecureString 'fixture-controller-secret' -AsPlainText -Force
    $configDocument = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'build_mihomo_config.ps1') -ProxyProfiles @($vlessProfile, $caProfile) -ControllerSecret $controllerSecret -MixedPort 17890 -ControllerPort 19090
    if ($configDocument.PSObject.TypeNames -notcontains 'ClashXY.ConnectionProfile' -or $configDocument.ProxyCount -ne 2) {
        throw 'Mihomo Config Builder returned an incorrect ConnectionProfile envelope.'
    }
    if ($configDocument.Ast['mixed-port'] -ne 17890 -or $configDocument.Ast['external-controller'] -ne '127.0.0.1:19090' -or $configDocument.Ast['allow-lan']) {
        throw 'Mihomo Config Builder returned incorrect listener safety settings.'
    }
    if ($configDocument.Ast.mode -ne 'rule' -or @($configDocument.Ast.proxies).Count -ne 2 -or @($configDocument.Ast['proxy-groups']).Count -ne 1) {
        throw 'Mihomo Config Builder returned an incomplete minimum AST.'
    }
    if ($configDocument.Ast['proxy-groups'][0].proxies[0] -ne 'fixture-mihomo-vless' -or $configDocument.Ast['proxy-groups'][0].proxies[1] -ne 'fixture-mihomo-hy2-ca') {
        throw 'Mihomo Config Builder did not preserve proxy names in the select group.'
    }
    if ($configDocument.Ast.rules[0] -ne 'MATCH,PROXY' -or $configDocument.ControllerSecret -isnot [securestring]) {
        throw 'Mihomo Config Builder omitted the final rule or SecureString Controller secret.'
    }

    $documentJson = $configDocument | ConvertTo-Json -Depth 50
    foreach ($forbidden in @('fixture-controller-secret', 'fixture-client-config-secret', 'fixture-hysteria2-client-password', 'fixture-hysteria2-obfs-password')) {
        if ($documentJson -match [regex]::Escape($forbidden)) {
            throw "ConnectionProfile serialization leaked a forbidden Secret: $forbidden"
        }
    }

    $duplicateRejected = $false
    try {
        & (Join-Path (Split-Path $PSScriptRoot -Parent) 'build_mihomo_config.ps1') -ProxyProfiles @($vlessProfile, $vlessProfile) -ControllerSecret $controllerSecret | Out-Null
    }
    catch {
        $duplicateRejected = $_.Exception.Message -match 'Duplicate ProxyProfile name'
    }
    if (-not $duplicateRejected) {
        throw 'Mihomo Config Builder accepted duplicate proxy names.'
    }

    $generatedSecretDocument = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'build_mihomo_config.ps1') -ProxyProfiles @($vlessProfile)
    if (-not $generatedSecretDocument.ControllerSecretGenerated -or $generatedSecretDocument.ControllerSecret -isnot [securestring]) {
        throw 'Mihomo Config Builder did not generate a SecureString Controller secret.'
    }
    $generatedControllerPlain = [System.Net.NetworkCredential]::new('', $generatedSecretDocument.ControllerSecret).Password
    try {
        if ($generatedControllerPlain.Length -lt 32) {
            throw 'Generated Controller secret was unexpectedly short.'
        }
    }
    finally {
        $generatedControllerPlain = $null
    }

    $quoteYaml = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'convert_to_yaml.ps1') -Ast ([ordered]@{ value = "fixture's value"; sequence = @('a:b') })
    if ($quoteYaml -notmatch "value: 'fixture''s value'" -or $quoteYaml -notmatch "- 'a:b'") {
        throw 'YAML Serializer did not safely quote scalar strings.'
    }

    $configPath = Join-Path $testRoot 'mihomo-fixture.yaml'
    $writeResult = & (Join-Path (Split-Path $PSScriptRoot -Parent) 'write_mihomo_config.ps1') -ConfigDocument $configDocument -OutputPath $configPath
    if (-not $writeResult.Written -or $writeResult.ProxyCount -ne 2 -or $writeResult.ByteLength -le 0 -or $writeResult.Sha256 -notmatch '^[a-f0-9]{64}$') {
        throw 'Mihomo Config Writer returned an incorrect safe summary.'
    }
    if (-not (Test-Path -LiteralPath $configPath) -or [System.IO.Path]::GetFullPath($configPath) -ne $writeResult.Path) {
        throw 'Mihomo Config Writer did not create the requested file.'
    }
    $configBytes = [System.IO.File]::ReadAllBytes($configPath)
    try {
        if ($configBytes.Length -ge 3 -and $configBytes[0] -eq 0xEF -and $configBytes[1] -eq 0xBB -and $configBytes[2] -eq 0xBF) {
            throw 'Mihomo Config Writer emitted an unexpected UTF-8 BOM.'
        }
    }
    finally {
        $configBytes = $null
    }

    $configText = [System.IO.File]::ReadAllText($configPath)
    foreach ($required in @(
        "mixed-port: 17890",
        "external-controller: '127.0.0.1:19090'",
        "type: 'vless'",
        "type: 'hysteria2'",
        "reality-opts:",
        "ports: '20000-20100,30000'",
        "rules:",
        "- 'MATCH,PROXY'",
        "'fixture-controller-secret'",
        "'fixture-client-config-secret'",
        "'fixture-hysteria2-client-password'",
        "'fixture-hysteria2-obfs-password'"
    )) {
        if ($configText -notmatch [regex]::Escape($required)) {
            throw "Generated Mihomo YAML omitted required content: $required"
        }
    }
    if ($configText -match 'System\\.Security\\.SecureString') {
        throw 'Generated Mihomo YAML serialized a SecureString type name instead of its value.'
    }

    $writeSummaryJson = $writeResult | ConvertTo-Json -Depth 10
    foreach ($forbidden in @('fixture-controller-secret', 'fixture-client-config-secret', 'fixture-hysteria2-client-password', 'fixture-hysteria2-obfs-password', 'reality-opts')) {
        if ($writeSummaryJson -match [regex]::Escape($forbidden)) {
            throw "Mihomo Config Writer summary leaked config content: $forbidden"
        }
    }
    if (@(Get-ChildItem -LiteralPath $testRoot -Filter '.mihomo-fixture.yaml.*.tmp').Count -ne 0) {
        throw 'Mihomo Config Writer left an atomic temp file behind.'
    }

    'PASS: structured Mihomo config AST, generic YAML serialization, SecureString boundary, atomic UTF-8 write, duplicate guard, and redacted summary'


    $deviceJson = & $labScript device create `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -DeviceName 'Fixture Workstation' `
        -InboundIds 7,9 `
        -AllowInsecureHttp
    $deviceResult = $deviceJson | ConvertFrom-Json -Depth 20
    if (-not $deviceResult.Created -or $deviceResult.Id -lt 100 -or $deviceResult.CredentialMode -ne 'generated') {
        throw 'device create did not return a successful generated-credential summary.'
    }
    if ($deviceResult.Name -notmatch '^clashxy-lab-fixture-workstation-[a-f0-9]{8}$') {
        throw 'device create did not use the required safe Client name prefix.'
    }
    if (@($deviceResult.InboundIds).Count -ne 2 -or $deviceResult.InboundIds[0] -ne 7 -or $deviceResult.InboundIds[1] -ne 9) {
        throw 'device create did not preserve the requested Inbound IDs.'
    }
    foreach ($forbidden in @('fixture-token', '"config"', '"links"', '"uuid"', '"password"', '"auth_str"')) {
        if ($deviceJson -match [regex]::Escape($forbidden)) {
            throw "device create output leaked a forbidden field or value: $forbidden"
        }
    }

    $clientsAfterCreateJson = & $labScript panel clients `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -AllowInsecureHttp
    $clientsAfterCreate = $clientsAfterCreateJson | ConvertFrom-Json -Depth 20
    $createdSummary = @($clientsAfterCreate.Clients | Where-Object Name -eq $deviceResult.Name)
    if ($createdSummary.Count -ne 1 -or $createdSummary[0].Id -ne $deviceResult.Id -or $createdSummary[0].InboundCount -ne 2) {
        throw 'Created device was not visible through the panel Client query.'
    }

    $safeDeviceJson = & $labScript device create `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -DeviceName 'Empty Inbounds' `
        -SafeSchemaOnly `
        -AllowInsecureHttp
    $safeDevice = $safeDeviceJson | ConvertFrom-Json -Depth 20
    if (-not $safeDevice.Created -or $safeDevice.InboundCount -ne 0 -or $safeDevice.CredentialMode -ne 'schema-only') {
        throw 'device create schema-only empty-Inbound summary was invalid.'
    }
    $emptyClientsJson = & $labScript panel clients `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -AllowInsecureHttp
    $emptyClients = $emptyClientsJson | ConvertFrom-Json -Depth 20
    $emptySummary = @($emptyClients.Clients | Where-Object Name -eq $safeDevice.Name)
    if ($emptySummary.Count -ne 1 -or $emptySummary[0].InboundCount -ne 0 -or @($emptySummary[0].InboundIds).Count -ne 0) {
        throw 'panel clients did not preserve an empty Inbound array.'
    }

    $deleteJson = & $labScript device delete `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -ClientId $deviceResult.Id `
        -ExpectedClientName $deviceResult.Name `
        -AllowInsecureHttp
    $deleteResult = $deleteJson | ConvertFrom-Json -Depth 20
    if (-not $deleteResult.Deleted -or -not $deleteResult.AbsentAfterDelete -or $deleteResult.Id -ne $deviceResult.Id -or $deleteResult.Name -ne $deviceResult.Name) {
        throw 'device delete did not confirm deletion of the generated-credential Client.'
    }
    if ($deleteJson -match [regex]::Escape('fixture-token')) {
        throw 'device delete output leaked the API Token.'
    }

    $guardRejected = $false
    try {
        & $labScript device delete `
            -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
            -ApiToken $token `
            -ClientId 11 `
            -ExpectedClientName 'fixture-client' `
            -AllowInsecureHttp | Out-Null
    }
    catch {
        $guardRejected = $_.Exception.Message -match 'lacks the clashxy-lab- prefix'
    }
    if (-not $guardRejected) {
        throw 'device delete did not protect a non-lab Client.'
    }

    $safeDeleteJson = & $labScript device delete `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -ClientId $safeDevice.Id `
        -ExpectedClientName $safeDevice.Name `
        -AllowInsecureHttp
    $safeDelete = $safeDeleteJson | ConvertFrom-Json -Depth 20
    if (-not $safeDelete.Deleted -or -not $safeDelete.AbsentAfterDelete) {
        throw 'device delete did not remove the schema-only Client.'
    }

    $clientsAfterDeleteJson = & $labScript panel clients `
        -BaseUrl "http://127.0.0.1:$($serverInfo.port)/app" `
        -ApiToken $token `
        -AllowInsecureHttp
    $clientsAfterDelete = $clientsAfterDeleteJson | ConvertFrom-Json -Depth 20
    if (@($clientsAfterDelete.Clients | Where-Object { $_.Name -like 'clashxy-lab-*' }).Count -ne 0) {
        throw 'Lab Clients remained after device delete.'
    }

    'PASS: device delete ID schema, prefix guard, absence verification, and redaction'


    'PASS: device create schema-only mode and empty-Inbound Client query'


    'PASS: device create prefix, full-schema request, panel visibility, and secret redaction'


    'PASS: panel clients structural summary and credential-field redaction'


    'PASS: panel inbounds structural summary and sensitive-field redaction'

    'PASS: panel token create, API v2 auth, delete, cleanup, and redaction'
    'PASS: panel login no-2FA, 2FA, failure, logout, and redaction'
    'PASS: 2S-UI probe flow and secret redaction'
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
    }

    if ($testRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testRoot)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
