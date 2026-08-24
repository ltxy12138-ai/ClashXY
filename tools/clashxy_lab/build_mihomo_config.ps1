[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [object[]]$ProxyProfiles,

    [securestring]$ControllerSecret,

    [ValidateRange(1, 65535)]
    [int]$MixedPort = 17890,

    [ValidateRange(1, 65535)]
    [int]$ControllerPort = 19090,

    [string]$ProxyGroupName = 'PROXY',

    [switch]$EnableTun,

    [ValidateSet('system', 'gvisor', 'mixed')]
    [string]$TunStack = 'mixed',

    [string]$TunDevice = 'ClashXY',

    [string]$TunIPv4Address = '198.18.0.1/30',

    [switch]$TunAutoRoute,

    [switch]$TunStrictRoute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($MixedPort -eq $ControllerPort) {
    throw 'MixedPort and ControllerPort must be different.'
}
if ([string]::IsNullOrWhiteSpace($ProxyGroupName)) {
    throw 'ProxyGroupName must not be empty.'
}
if ($EnableTun -and ($TunDevice -notmatch '^[A-Za-z][A-Za-z0-9-]{0,30}$')) {
    throw 'TunDevice must start with a letter and contain only letters, digits, or hyphens (maximum 31 characters).'
}
if ($EnableTun) {
    $cidrParts = [string]$TunIPv4Address -split '/', 2
    $parsedAddress = $null
    $prefixLength = 0
    if ($cidrParts.Count -ne 2 -or
        -not [System.Net.IPAddress]::TryParse($cidrParts[0], [ref]$parsedAddress) -or
        $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
        -not [int]::TryParse($cidrParts[1], [ref]$prefixLength) -or
        $prefixLength -ne 30) {
        throw 'TunIPv4Address must be a valid IPv4 /30 CIDR.'
    }
    $addressBytes = $parsedAddress.GetAddressBytes()
    if (($addressBytes[3] -band 3) -ne 1) {
        throw 'TunIPv4Address must be the first usable address in its /30.'
    }
}
if (-not $EnableTun -and ($TunAutoRoute -or $TunStrictRoute)) {
    throw 'TunAutoRoute and TunStrictRoute require EnableTun.'
}
if ($TunStrictRoute -and -not $TunAutoRoute) {
    throw 'TunStrictRoute requires TunAutoRoute.'
}
if (@($ProxyProfiles).Count -eq 0) {
    throw 'At least one ProxyProfile is required.'
}

$names = [System.Collections.Generic.List[string]]::new()
$nameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$proxyMaps = [System.Collections.Generic.List[object]]::new()

foreach ($profile in @($ProxyProfiles)) {
    if ($null -eq $profile -or [string]$profile.Protocol -notin @('vless', 'hysteria2')) {
        throw 'Only VLESS and Hysteria2 ProxyProfiles are supported.'
    }
    $fields = $profile.PSObject.Properties['Fields'].Value
    if ($fields -isnot [System.Collections.IDictionary]) {
        throw 'ProxyProfile Fields must be a dictionary.'
    }
    if (-not $fields.Contains('name') -or [string]::IsNullOrWhiteSpace([string]$fields['name'])) {
        throw 'Every ProxyProfile requires a non-empty name.'
    }
    if (-not $fields.Contains('type') -or [string]$fields['type'] -cne [string]$profile.Protocol) {
        throw 'ProxyProfile type does not match its Protocol.'
    }

    $profileName = [string]$fields['name']
    if (-not $nameSet.Add($profileName)) {
        throw "Duplicate ProxyProfile name '$profileName'."
    }

    foreach ($sensitiveField in @($profile.SensitiveFieldNames)) {
        $sensitiveName = [string]$sensitiveField
        if ($fields.Contains($sensitiveName) -and $fields[$sensitiveName] -isnot [securestring]) {
            throw "Sensitive ProxyProfile field '$sensitiveName' must be a SecureString."
        }
    }

    $names.Add($profileName)
    $proxyMaps.Add($fields)
}

$generatedControllerSecret = $false
if ($null -eq $ControllerSecret) {
    $secretBytes = [byte[]]::new(32)
    $secretPlain = $null
    try {
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($secretBytes)
        $secretPlain = [Convert]::ToBase64String($secretBytes)
        $ControllerSecret = ConvertTo-SecureString $secretPlain -AsPlainText -Force
        $generatedControllerSecret = $true
    }
    finally {
        [Array]::Clear($secretBytes, 0, $secretBytes.Length)
        $secretPlain = $null
    }
}
if ([System.Net.NetworkCredential]::new('', $ControllerSecret).Password.Length -lt 16) {
    throw 'ControllerSecret must contain at least 16 characters.'
}

$proxyGroup = [ordered]@{
    name    = $ProxyGroupName
    type    = 'select'
    proxies = @($names)
}

$ast = [ordered]@{
    'mixed-port'         = $MixedPort
    'allow-lan'          = $false
    mode                 = 'rule'
    'log-level'          = 'info'
    ipv6                 = $true
    'external-controller' = "127.0.0.1:$ControllerPort"
    secret               = $ControllerSecret
    proxies              = @($proxyMaps)
    'proxy-groups'       = @($proxyGroup)
    rules                = @("MATCH,$ProxyGroupName")
}

if ($EnableTun) {
    $ast['dns'] = [ordered]@{
        enable          = $false
        'fake-ip-range' = $TunIPv4Address
    }
    $ast['tun'] = [ordered]@{
        enable                  = $true
        stack                   = $TunStack
        device                  = $TunDevice
        'auto-route'            = [bool]$TunAutoRoute
        'auto-detect-interface' = $true
        'strict-route'          = [bool]$TunStrictRoute
    }
}

[pscustomobject][ordered]@{
    PSTypeName                = 'ClashXY.ConnectionProfile'
    SchemaVersion             = 1
    Ast                       = $ast
    ProxyNames                = @($names)
    ProxyCount                = $names.Count
    MixedPort                 = $MixedPort
    ControllerAddress         = "127.0.0.1:$ControllerPort"
    ControllerSecret          = $ControllerSecret
    TunEnabled                = [bool]$EnableTun
    TunStack                  = if ($EnableTun) { $TunStack } else { $null }
    TunDevice                 = if ($EnableTun) { $TunDevice } else { $null }
    TunIPv4Address            = if ($EnableTun) { $TunIPv4Address } else { $null }
    TunAutoRoute              = if ($EnableTun) { [bool]$TunAutoRoute } else { $false }
    ControllerSecretGenerated = $generatedControllerSecret
    SensitivePaths            = @(
        'secret',
        'proxies[].uuid',
        'proxies[].password',
        'proxies[].obfs-password'
    )
}
