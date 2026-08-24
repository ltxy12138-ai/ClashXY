[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [securestring]$ApiToken,

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

function Get-OptionalProperty {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

if ($null -eq $ApiToken) {
    $ApiToken = Read-Host 'API Token' -AsSecureString
}

$panelBase = Resolve-PanelBaseUrl -Uri $BaseUrl -AllowHttp:$AllowInsecureHttp
$tokenPlain = $null

try {
    $tokenPlain = [System.Net.NetworkCredential]::new('', $ApiToken).Password
    if ([string]::IsNullOrWhiteSpace($tokenPlain)) {
        throw 'API Token must not be empty.'
    }

    $response = Invoke-WebRequest `
        -Uri ([uri]::new($panelBase, 'apiv2/clients')) `
        -Method Get `
        -Headers @{ Token = $tokenPlain } `
        -SkipHttpErrorCheck `
        -ErrorAction Stop

    $httpStatus = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Client query returned a non-JSON response (HTTP $httpStatus)."
    }

    $properties = @($envelope.PSObject.Properties.Name)
    if (-not (($properties -contains 'success') -and ($properties -contains 'msg') -and ($properties -contains 'obj'))) {
        throw "Client query returned an unexpected response envelope (HTTP $httpStatus)."
    }
    if (-not [bool]$envelope.success) {
        $message = [string]$envelope.msg
        if (-not [string]::IsNullOrEmpty($tokenPlain)) {
            $message = $message.Replace($tokenPlain, '<redacted>')
        }
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = 'request rejected'
        }
        if ($message.Length -gt 200) {
            $message = $message.Substring(0, 200) + '…'
        }
        throw "Client query failed (HTTP $httpStatus): $message"
    }

    $payload = if ($null -eq $envelope.obj) { $null } else { Get-OptionalProperty -InputObject $envelope.obj -Name 'clients' }
    if ($null -eq $payload) {
        $payload = @()
    }

    $summaries = @(
        foreach ($client in @($payload)) {
            if ($null -eq $client) {
                continue
            }

            $inboundIdsValue = Get-OptionalProperty -InputObject $client -Name 'inbounds'
            $inboundIds = if ($null -eq $inboundIdsValue) { @() } else { @($inboundIdsValue) }
            [pscustomobject][ordered]@{
                Id           = Get-OptionalProperty -InputObject $client -Name 'id'
                Name         = [string](Get-OptionalProperty -InputObject $client -Name 'name')
                Enabled      = [bool](Get-OptionalProperty -InputObject $client -Name 'enable')
                Group        = [string](Get-OptionalProperty -InputObject $client -Name 'group')
                InboundIds   = @($inboundIds)
                InboundCount = @($inboundIds).Count
                UpBytes      = Get-OptionalProperty -InputObject $client -Name 'up'
                DownBytes    = Get-OptionalProperty -InputObject $client -Name 'down'
                QuotaBytes   = Get-OptionalProperty -InputObject $client -Name 'volume'
                ExpiryUnix   = Get-OptionalProperty -InputObject $client -Name 'expiry'
                LimitIp      = Get-OptionalProperty -InputObject $client -Name 'limitIp'
            }
        }
    )

    $sequence = if ($null -eq $envelope.obj) { $null } else { Get-OptionalProperty -InputObject $envelope.obj -Name 'clientsSeq' }
    [pscustomobject][ordered]@{
        SchemaVersion     = 1
        QueriedAtUtc      = [datetime]::UtcNow.ToString('o')
        BaseUrl           = $panelBase.AbsoluteUri
        InsecureHttpOptIn = [bool]$AllowInsecureHttp
        HttpStatus        = $httpStatus
        SnapshotSequence  = $sequence
        Count             = $summaries.Count
        Clients           = $summaries
    }
}
finally {
    $tokenPlain = $null
}
