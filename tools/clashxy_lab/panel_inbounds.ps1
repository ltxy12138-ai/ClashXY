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
        -Uri ([uri]::new($panelBase, 'apiv2/inbounds')) `
        -Method Get `
        -Headers @{ Token = $tokenPlain } `
        -SkipHttpErrorCheck `
        -ErrorAction Stop

    $httpStatus = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Inbound query returned a non-JSON response (HTTP $httpStatus)."
    }

    $properties = @($envelope.PSObject.Properties.Name)
    if (-not (($properties -contains 'success') -and ($properties -contains 'msg') -and ($properties -contains 'obj'))) {
        throw "Inbound query returned an unexpected response envelope (HTTP $httpStatus)."
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
        throw "Inbound query failed (HTTP $httpStatus): $message"
    }

    $payload = if ($null -eq $envelope.obj) { $null } else { Get-OptionalProperty -InputObject $envelope.obj -Name 'inbounds' }
    if ($null -eq $payload) {
        $payload = @()
    }

    $summaries = @(
        foreach ($inbound in @($payload)) {
            if ($null -eq $inbound) {
                continue
            }

            $users = Get-OptionalProperty -InputObject $inbound -Name 'users'
            [pscustomobject][ordered]@{
                Id        = Get-OptionalProperty -InputObject $inbound -Name 'id'
                Type      = [string](Get-OptionalProperty -InputObject $inbound -Name 'type')
                Tag       = [string](Get-OptionalProperty -InputObject $inbound -Name 'tag')
                Listen    = [string](Get-OptionalProperty -InputObject $inbound -Name 'listen')
                Port      = Get-OptionalProperty -InputObject $inbound -Name 'listen_port'
                TlsId     = Get-OptionalProperty -InputObject $inbound -Name 'tls_id'
                NodeId    = Get-OptionalProperty -InputObject $inbound -Name 'node_id'
                UserCount = if ($null -eq $users) { 0 } else { @($users).Count }
            }
        }
    )

    [pscustomobject][ordered]@{
        SchemaVersion     = 1
        QueriedAtUtc      = [datetime]::UtcNow.ToString('o')
        BaseUrl           = $panelBase.AbsoluteUri
        InsecureHttpOptIn = [bool]$AllowInsecureHttp
        HttpStatus        = $httpStatus
        Count             = $summaries.Count
        Inbounds          = $summaries
    }
}
finally {
    $tokenPlain = $null
}
