[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [securestring]$ApiToken,

    [Parameter(Mandatory)]
    [ValidateRange(1, 4294967295)]
    [uint]$InboundId,

    [Parameter(Mandatory)]
    [ValidateRange(1, 4294967295)]
    [uint]$ClientId,

    [switch]$AllowInsecureHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PanelBaseUrl {
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [switch]$AllowHttp
    )

    if ($Uri.Scheme -notin @('https', 'http')) {
        throw 'Panel URL must use HTTPS or HTTP.'
    }
    if ($Uri.UserInfo) {
        throw 'Panel URL must not contain credentials.'
    }
    if ($Uri.Query -or $Uri.Fragment) {
        throw 'Panel URL must not contain a query string or fragment.'
    }
    if ($Uri.Scheme -eq 'http' -and -not $AllowHttp) {
        throw 'Plain HTTP is disabled. Use -AllowInsecureHttp only for an explicit development test.'
    }

    $builder = [System.UriBuilder]::new($Uri)
    $path = $builder.Path
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = '/'
    }
    if (-not $path.EndsWith('/')) {
        $path += '/'
    }
    $builder.Path = $path
    $builder.Query = ''
    $builder.Fragment = ''
    return $builder.Uri
}

function Invoke-ApiV2Object {
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Token
    )

    $response = Invoke-WebRequest -Uri $Uri -Method Get -Headers @{ Token = $Token } -SkipHttpErrorCheck -ErrorAction Stop
    $status = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "API v2 returned a non-JSON response (HTTP $status)."
    }
    if (-not [bool]$envelope.success) {
        throw "API v2 request was rejected (HTTP $status)."
    }
    return $envelope.obj
}

if ($null -eq $ApiToken) {
    $ApiToken = Read-Host 'API Token' -AsSecureString
}

$panelBase = Resolve-PanelBaseUrl -Uri $BaseUrl -AllowHttp:$AllowInsecureHttp
$tokenPlain = $null
$model = $null

try {
    $tokenPlain = [System.Net.NetworkCredential]::new('', $ApiToken).Password
    if ([string]::IsNullOrWhiteSpace($tokenPlain)) {
        throw 'API Token must not be empty.'
    }

    $inboundObj = Invoke-ApiV2Object -Uri ([uri]::new($panelBase, ('apiv2/inbounds?id=' + $InboundId))) -Token $tokenPlain
    $clientObj = Invoke-ApiV2Object -Uri ([uri]::new($panelBase, ('apiv2/clients?id=' + $ClientId))) -Token $tokenPlain
    $inbound = @($inboundObj.inbounds | Where-Object { $null -ne $_ -and [uint]$_.id -eq $InboundId }) | Select-Object -First 1
    $client = @($clientObj.clients | Where-Object { $null -ne $_ -and [uint]$_.id -eq $ClientId }) | Select-Object -First 1
    if ($null -eq $inbound) {
        throw "Inbound ID $InboundId was not returned."
    }
    if ($null -eq $client) {
        throw "Client ID $ClientId was not returned."
    }

    $model = & (Join-Path $PSScriptRoot 'extract_hysteria2.ps1') -Inbound $inbound -Client $client
    $endpointSummaries = @(
        foreach ($endpoint in @($model.Endpoints)) {
            [pscustomobject][ordered]@{
                Server              = $endpoint.Server
                Port                = $endpoint.Port
                Remark              = $endpoint.Remark
                Security            = $endpoint.Security
                ServerName          = $endpoint.ServerName
                Alpn                = @($endpoint.Alpn)
                Insecure            = $endpoint.Insecure
                Fingerprint         = $endpoint.Fingerprint
                CertificatePinCount = @($endpoint.CertificatePublicKeySha256Pins).Count
            }
        }
    )

    [pscustomobject][ordered]@{
        SchemaVersion       = 1
        ExtractedAtUtc      = [datetime]::UtcNow.ToString('o')
        BaseUrl             = $panelBase.AbsoluteUri
        InsecureHttpOptIn   = [bool]$AllowInsecureHttp
        Protocol            = $model.Protocol
        InboundId           = $model.InboundId
        InboundTag          = $model.InboundTag
        ClientId            = $model.ClientId
        ClientName          = $model.ClientName
        PasswordPresent     = $model.PasswordPresent
        ClientUpMbps        = $model.ClientUpMbps
        ClientDownMbps      = $model.ClientDownMbps
        ServerPorts         = @($model.ServerPorts)
        TcpFastOpen         = $model.TcpFastOpen
        ObfsType            = $model.ObfsType
        ObfsPasswordPresent = $model.ObfsPasswordPresent
        EndpointCount       = @($endpointSummaries).Count
        Endpoints           = $endpointSummaries
    }
}
finally {
    $model = $null
    $tokenPlain = $null
}
