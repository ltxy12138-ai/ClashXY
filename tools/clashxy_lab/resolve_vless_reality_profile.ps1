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

    [ValidateRange(0, 1024)]
    [int]$EndpointIndex = 0,

    [string]$ProfileName,

    [switch]$AllowInsecureHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PanelBaseUrl {
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [switch]$AllowHttp
    )

    if ($Uri.Scheme -notin @('https', 'http')) {
        throw 'Panel URL must use HTTPS or HTTP.'
    }
    if ($Uri.UserInfo -or $Uri.Query -or $Uri.Fragment) {
        throw 'Panel URL must not contain credentials, query, or fragment.'
    }
    if ($Uri.Scheme -eq 'http' -and -not $AllowHttp) {
        throw 'Plain HTTP is disabled. Use -AllowInsecureHttp only for an explicit development test.'
    }
    $builder = [System.UriBuilder]::new($Uri)
    $path = if ([string]::IsNullOrWhiteSpace($builder.Path)) { '/' } else { $builder.Path }
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
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][string]$Token
    )

    $response = Invoke-WebRequest -Uri $Uri -Method Get -Headers @{ Token = $Token } -SkipHttpErrorCheck -ErrorAction Stop
    $status = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    }
    catch {
        throw ('API v2 returned invalid JSON with HTTP status ' + $status + '.')
    }
    if (-not [bool]$envelope.success) {
        throw ('API v2 request was rejected with HTTP status ' + $status + '.')
    }
    return $envelope.obj
}

if ($null -eq $ApiToken) {
    $ApiToken = Read-Host 'API Token' -AsSecureString
}

$panelBase = Resolve-PanelBaseUrl -Uri $BaseUrl -AllowHttp:$AllowInsecureHttp
$tokenPlain = $null
$connection = $null
$proxyProfile = $null

try {
    $tokenPlain = [System.Net.NetworkCredential]::new('', $ApiToken).Password
    if ([string]::IsNullOrWhiteSpace($tokenPlain)) {
        throw 'API Token must not be empty.'
    }

    $inboundObject = Invoke-ApiV2Object -Uri ([uri]::new($panelBase, ('apiv2/inbounds?id=' + $InboundId))) -Token $tokenPlain
    $clientObject = Invoke-ApiV2Object -Uri ([uri]::new($panelBase, ('apiv2/clients?id=' + $ClientId))) -Token $tokenPlain
    $inbound = @($inboundObject.inbounds | Where-Object { $null -ne $_ -and [uint]$_.id -eq $InboundId }) | Select-Object -First 1
    $client = @($clientObject.clients | Where-Object { $null -ne $_ -and [uint]$_.id -eq $ClientId }) | Select-Object -First 1
    if ($null -eq $inbound) {
        throw ('Inbound ID ' + $InboundId + ' was not returned.')
    }
    if ($null -eq $client) {
        throw ('Client ID ' + $ClientId + ' was not returned.')
    }

    $connection = & (Join-Path $PSScriptRoot 'extract_vless_reality.ps1') -Inbound $inbound -Client $client
    $mapParams = @{
        Connection    = $connection
        EndpointIndex = $EndpointIndex
    }
    if (-not [string]::IsNullOrWhiteSpace($ProfileName)) {
        $mapParams.Name = $ProfileName
    }
    $proxyProfile = & (Join-Path $PSScriptRoot 'map_vless_reality_profile.ps1') @mapParams
}
finally {
    $connection = $null
    $tokenPlain = $null
}

return $proxyProfile
