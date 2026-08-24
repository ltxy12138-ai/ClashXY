[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [securestring]$ApiToken,

    [Parameter(Mandatory)]
    [ValidateRange(1, [uint]::MaxValue)]
    [uint]$ClientId,

    [string]$ExpectedClientName,

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

function Invoke-ClientList {
    param(
        [Parameter(Mandatory)]
        [uri]$PanelBase,

        [Parameter(Mandatory)]
        [string]$Token
    )

    $response = Invoke-WebRequest `
        -Uri ([uri]::new($PanelBase, 'apiv2/clients')) `
        -Method Get `
        -Headers @{ Token = $Token } `
        -SkipHttpErrorCheck `
        -ErrorAction Stop
    $status = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Client list returned a non-JSON response (HTTP $status)."
    }
    if (-not [bool]$envelope.success) {
        throw "Client list was rejected (HTTP $status)."
    }
    return @($envelope.obj.clients)
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

    $before = @(Invoke-ClientList -PanelBase $panelBase -Token $tokenPlain)
    $target = @($before | Where-Object { $null -ne $_ -and ($_.PSObject.Properties.Name -contains 'id') -and [uint]$_.id -eq $ClientId }) | Select-Object -First 1
    if ($null -eq $target) {
        throw "Client ID $ClientId does not exist; nothing was deleted."
    }

    $targetName = [string]$target.name
    if (-not $targetName.StartsWith('clashxy-lab-', [System.StringComparison]::Ordinal)) {
        throw "Refusing to delete Client ID $ClientId because its name lacks the clashxy-lab- prefix."
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedClientName) -and $targetName -cne $ExpectedClientName) {
        throw "Refusing to delete Client ID $ClientId because its name does not match -ExpectedClientName."
    }

    $response = Invoke-WebRequest `
        -Uri ([uri]::new($panelBase, 'apiv2/save')) `
        -Method Post `
        -Headers @{ Token = $tokenPlain; 'X-Requested-With' = 'XMLHttpRequest' } `
        -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' `
        -Body @{ object = 'clients'; action = 'del'; data = ($ClientId | ConvertTo-Json -Compress); initUsers = '' } `
        -SkipHttpErrorCheck `
        -ErrorAction Stop

    $httpStatus = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Device delete returned a non-JSON response (HTTP $httpStatus)."
    }
    if (-not [bool]$envelope.success) {
        throw "Device delete was rejected (HTTP $httpStatus)."
    }

    $after = @(Invoke-ClientList -PanelBase $panelBase -Token $tokenPlain)
    $absent = @($after | Where-Object { $null -ne $_ -and ($_.PSObject.Properties.Name -contains 'id') -and [uint]$_.id -eq $ClientId }).Count -eq 0
    if (-not $absent) {
        throw "Device delete returned success but Client ID $ClientId is still present."
    }

    [pscustomobject][ordered]@{
        SchemaVersion     = 1
        DeletedAtUtc      = [datetime]::UtcNow.ToString('o')
        BaseUrl           = $panelBase.AbsoluteUri
        InsecureHttpOptIn = [bool]$AllowInsecureHttp
        HttpStatus        = $httpStatus
        Id                = $ClientId
        Name              = $targetName
        Deleted           = $true
        AbsentAfterDelete = $true
    }
}
finally {
    $tokenPlain = $null
}
