[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [securestring]$ApiToken,
    [securestring]$VlessUuid,


    [string]$DeviceName,

    [uint[]]$InboundIds = @(),

    [switch]$SafeSchemaOnly,

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

function New-RandomHex {
    param(
        [ValidateRange(1, 128)]
        [int]$ByteCount
    )

    $bytes = [byte[]]::new($ByteCount)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    try {
        return [System.Convert]::ToHexString($bytes).ToLowerInvariant()
    }
    finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
}

function New-ClientConfig {
    param(
        [Parameter(Mandatory)][string]$ClientName,
        [securestring]$RequestedVlessUuid
    )

    $sharedPassword = New-RandomHex -ByteCount 16
    $ss16Password = New-RandomHex -ByteCount 8
    $ss32Password = New-RandomHex -ByteCount 16
    $uuid = if ($null -eq $RequestedVlessUuid) {
        [guid]::NewGuid().ToString()
    }
    else {
        [System.Net.NetworkCredential]::new('', $RequestedVlessUuid).Password
    }
    $parsedUuid = [guid]::Empty
    if (-not [guid]::TryParse($uuid, [ref]$parsedUuid)) {
        $uuid = $null
        throw 'VlessUuid must contain a valid GUID.'
    }
    $uuid = $parsedUuid.ToString()

    return [ordered]@{
        mixed       = [ordered]@{ username = $ClientName; password = $sharedPassword }
        socks       = [ordered]@{ username = $ClientName; password = $sharedPassword }
        http        = [ordered]@{ username = $ClientName; password = $sharedPassword }
        shadowsocks = [ordered]@{ name = $ClientName; password = $ss32Password }
        shadowsocks16 = [ordered]@{ name = $ClientName; password = $ss16Password }
        shadowtls   = [ordered]@{ name = $ClientName; password = $ss32Password }
        vmess       = [ordered]@{ name = $ClientName; uuid = $uuid; alterId = 0 }
        vless       = [ordered]@{ name = $ClientName; uuid = $uuid; flow = 'xtls-rprx-vision' }
        anytls      = [ordered]@{ name = $ClientName; password = $sharedPassword }
        trojan      = [ordered]@{ name = $ClientName; password = $sharedPassword }
        naive       = [ordered]@{ username = $ClientName; password = $sharedPassword }
        hysteria    = [ordered]@{ name = $ClientName; auth_str = $sharedPassword }
        tuic        = [ordered]@{ name = $ClientName; uuid = $uuid; password = $sharedPassword }
        hysteria2   = [ordered]@{ name = $ClientName; password = $sharedPassword }
    }
}

function Protect-ErrorText {
    param(
        [AllowNull()]
        [string]$Text,

        [AllowNull()]
        [string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return 'request failed'
    }
    $safe = if ([string]::IsNullOrEmpty($Token)) { $Text } else { $Text.Replace($Token, '<redacted>') }
    $safe = $safe -replace '(?i)(token|password|secret|uuid|auth_str)\s*[:=]\s*[^\s,;]+', '$1=<redacted>'
    if ($safe.Length -gt 200) {
        $safe = $safe.Substring(0, 200) + '…'
    }
    return $safe
}

if ($null -eq $ApiToken) {
    $ApiToken = Read-Host 'API Token' -AsSecureString
}

$panelBase = Resolve-PanelBaseUrl -Uri $BaseUrl -AllowHttp:$AllowInsecureHttp
$tokenPlain = $null
$config = $null
$dataJson = $null
$createdId = $null
$createdAt = $null
$serverCreated = $false

try {
    $tokenPlain = [System.Net.NetworkCredential]::new('', $ApiToken).Password
    if ([string]::IsNullOrWhiteSpace($tokenPlain)) {
        throw 'API Token must not be empty.'
    }

    $devicePart = if ([string]::IsNullOrWhiteSpace($DeviceName)) { [Environment]::MachineName } else { $DeviceName }
    $devicePart = ($devicePart.ToLowerInvariant() -replace '[^a-z0-9_-]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($devicePart)) {
        $devicePart = 'device'
    }
    if ($devicePart.Length -gt 32) {
        $devicePart = $devicePart.Substring(0, 32).Trim('-')
    }
    $clientName = 'clashxy-lab-' + $devicePart + '-' + (New-RandomHex -ByteCount 4)

    $config = if ($SafeSchemaOnly) { [ordered]@{} } else { New-ClientConfig -ClientName $clientName -RequestedVlessUuid $VlessUuid }
    $payload = [ordered]@{
        enable     = $true
        name       = $clientName
        config     = $config
        inbounds   = @($InboundIds)
        links      = @()
        volume     = 0
        expiry     = 0
        desc       = ''
        group      = ''
        limitIp    = 0
        delayStart = $false
        autoReset  = $true
        resetDays  = 30
        nextReset  = 0
    }
    $dataJson = $payload | ConvertTo-Json -Depth 20 -Compress

    $response = Invoke-WebRequest `
        -Uri ([uri]::new($panelBase, 'apiv2/save')) `
        -Method Post `
        -Headers @{ Token = $tokenPlain; 'X-Requested-With' = 'XMLHttpRequest' } `
        -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' `
        -Body @{ object = 'clients'; action = 'new'; data = $dataJson; initUsers = '' } `
        -SkipHttpErrorCheck `
        -ErrorAction Stop

    $httpStatus = [int]$response.StatusCode
    try {
        $envelope = ([string]$response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "Device create returned a non-JSON response (HTTP $httpStatus)."
    }
    if (-not [bool]$envelope.success) {
        throw ('Device create was rejected: ' + (Protect-ErrorText -Text ([string]$envelope.msg) -Token $tokenPlain))
    }

    $serverCreated = $true
    $created = @($envelope.obj.clients | Where-Object name -eq $clientName) | Select-Object -First 1
    if ($null -eq $created) {
        throw 'Device create succeeded but the Client was absent from the returned snapshot.'
    }
    $createdId = [uint]$created.id
    $createdAt = if ($created.PSObject.Properties.Name -contains 'createdAt') { [int64]$created.createdAt } else { $null }

    [pscustomobject][ordered]@{
        SchemaVersion     = 1
        CreatedAtUtc      = [datetime]::UtcNow.ToString('o')
        BaseUrl           = $panelBase.AbsoluteUri
        InsecureHttpOptIn = [bool]$AllowInsecureHttp
        HttpStatus        = $httpStatus
        Id                = $createdId
        Name              = $clientName
        Enabled           = [bool]$created.enable
        InboundIds        = @($InboundIds)
        InboundCount      = @($InboundIds).Count
        CredentialMode    = if ($SafeSchemaOnly) { 'schema-only' } else { 'generated' }
        ServerCreatedAt   = $createdAt
        Created           = $true
    }
}
catch {
    if ($serverCreated -and $null -eq $createdId) {
        try {
            $list = Invoke-RestMethod `
                -Uri ([uri]::new($panelBase, 'apiv2/clients')) `
                -Method Get `
                -Headers @{ Token = $tokenPlain } `
                -ErrorAction Stop
            $rollbackClient = @($list.obj.clients | Where-Object name -eq $clientName) | Select-Object -First 1
            if ($null -ne $rollbackClient) {
                $createdId = [uint]$rollbackClient.id
            }
        }
        catch {
        }
    }
    if ($serverCreated -and $null -ne $createdId) {
        try {
            Invoke-RestMethod `
                -Uri ([uri]::new($panelBase, 'apiv2/save')) `
                -Method Post `
                -Headers @{ Token = $tokenPlain; 'X-Requested-With' = 'XMLHttpRequest' } `
                -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' `
                -Body @{ object = 'clients'; action = 'del'; data = ($createdId | ConvertTo-Json -Compress); initUsers = '' } `
                -ErrorAction Stop | Out-Null
        }
        catch {
        }
    }
    $message = Protect-ErrorText -Text $_.Exception.Message -Token $tokenPlain
    throw $message
}
finally {
    $dataJson = $null
    $config = $null
    $tokenPlain = $null
}
