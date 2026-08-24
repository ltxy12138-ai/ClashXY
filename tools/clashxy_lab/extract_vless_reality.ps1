[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [object]$Inbound,

    [Parameter(Mandatory)]
    [object]$Client
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
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

function ConvertTo-JsonObject {
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$FieldName
    )

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $null
        }
        try {
            return $Value | ConvertFrom-Json -Depth 100
        }
        catch {
            throw "$FieldName is not valid JSON."
        }
    }
    return $Value
}

function ConvertTo-Map {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return @{}
    }
    return ($Value | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json -Depth 100 -AsHashtable
}

function Merge-Map {
    param(
        [System.Collections.IDictionary]$Base,
        [System.Collections.IDictionary]$Override
    )

    $result = @{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }
    foreach ($key in $Override.Keys) {
        $result[$key] = $Override[$key]
    }
    return $result
}

$inboundType = [string](Get-PropertyValue -InputObject $Inbound -Name 'type')
if ($inboundType -cne 'vless') {
    throw "Expected a vless Inbound, received '$inboundType'."
}

$inboundId = [uint](Get-PropertyValue -InputObject $Inbound -Name 'id')
$clientId = [uint](Get-PropertyValue -InputObject $Client -Name 'id')
$clientName = [string](Get-PropertyValue -InputObject $Client -Name 'name')
$clientInboundIds = @(Get-PropertyValue -InputObject $Client -Name 'inbounds')
if ($clientInboundIds.Count -eq 0 -or @($clientInboundIds | Where-Object { [uint]$_ -eq $inboundId }).Count -eq 0) {
    throw "Client ID $clientId is not bound to Inbound ID $inboundId."
}

$config = ConvertTo-JsonObject -Value (Get-PropertyValue -InputObject $Client -Name 'config') -FieldName 'client.config'
if ($null -eq $config) {
    throw 'Client config is missing.'
}
$vlessConfig = Get-PropertyValue -InputObject $config -Name 'vless'
if ($null -eq $vlessConfig) {
    throw 'Client config.vless is missing.'
}
$uuidPlain = [string](Get-PropertyValue -InputObject $vlessConfig -Name 'uuid')
if ([string]::IsNullOrWhiteSpace($uuidPlain)) {
    throw 'Client config.vless.uuid is missing.'
}
$flow = [string](Get-PropertyValue -InputObject $vlessConfig -Name 'flow')

$outJson = ConvertTo-JsonObject -Value (Get-PropertyValue -InputObject $Inbound -Name 'out_json') -FieldName 'inbound.out_json'
if ($null -eq $outJson) {
    throw 'Inbound out_json is missing.'
}
if ([string](Get-PropertyValue -InputObject $outJson -Name 'type') -cne 'vless') {
    throw 'Inbound out_json is not a vless client configuration.'
}

$transportObject = ConvertTo-JsonObject -Value (Get-PropertyValue -InputObject $outJson -Name 'transport') -FieldName 'inbound.out_json.transport'
$transportMap = ConvertTo-Map -Value $transportObject
$transportType = if ($transportMap.ContainsKey('type') -and -not [string]::IsNullOrWhiteSpace([string]$transportMap.type)) {
    [string]$transportMap.type
}
else {
    'tcp'
}
$headers = if ($transportMap.ContainsKey('headers')) { ConvertTo-Map -Value $transportMap.headers } else { @{} }
$hostValues = @()
if ($transportMap.ContainsKey('host')) {
    $hostValues = @($transportMap.host)
}
elseif ($headers.ContainsKey('Host')) {
    $hostValues = @([string]$headers['Host'])
}
$transport = [pscustomobject][ordered]@{
    Type                = $transportType
    Path                = if ($transportMap.ContainsKey('path')) { [string]$transportMap.path } else { '' }
    Host                = $hostValues
    Headers             = $headers
    Method              = if ($transportMap.ContainsKey('method')) { [string]$transportMap.method } else { '' }
    ServiceName         = if ($transportMap.ContainsKey('service_name')) { [string]$transportMap.service_name } else { '' }
    MaxEarlyData        = if ($transportMap.ContainsKey('max_early_data')) { $transportMap.max_early_data } else { $null }
    EarlyDataHeaderName = if ($transportMap.ContainsKey('early_data_header_name')) { [string]$transportMap.early_data_header_name } else { '' }
}

$baseTlsMap = ConvertTo-Map -Value (Get-PropertyValue -InputObject $outJson -Name 'tls')
$rawAddrs = ConvertTo-JsonObject -Value (Get-PropertyValue -InputObject $Inbound -Name 'addrs') -FieldName 'inbound.addrs'
$addressList = @($rawAddrs)
if ($addressList.Count -eq 0 -or ($addressList.Count -eq 1 -and $null -eq $addressList[0])) {
    $addressList = @(
        [pscustomobject]@{
            server      = Get-PropertyValue -InputObject $outJson -Name 'server'
            server_port = Get-PropertyValue -InputObject $outJson -Name 'server_port'
            remark      = Get-PropertyValue -InputObject $Inbound -Name 'tag'
        }
    )
}

$endpoints = @(
    foreach ($address in $addressList) {
        if ($null -eq $address) {
            continue
        }
        $server = [string](Get-PropertyValue -InputObject $address -Name 'server')
        $port = [int](Get-PropertyValue -InputObject $address -Name 'server_port')
        if ([string]::IsNullOrWhiteSpace($server) -or $port -le 0 -or $port -gt 65535) {
            throw 'VLESS endpoint requires a non-empty server and a port from 1 to 65535.'
        }

        $addressTlsValue = Get-PropertyValue -InputObject $address -Name 'tls'
        $tlsMap = if ($null -eq $addressTlsValue) {
            Merge-Map -Base $baseTlsMap -Override @{}
        }
        else {
            Merge-Map -Base $baseTlsMap -Override (ConvertTo-Map -Value $addressTlsValue)
        }
        $tlsEnabled = $tlsMap.ContainsKey('enabled') -and [bool]$tlsMap.enabled
        $realityMap = if ($tlsMap.ContainsKey('reality')) { ConvertTo-Map -Value $tlsMap.reality } else { @{} }
        $realityEnabled = $realityMap.ContainsKey('enabled') -and [bool]$realityMap.enabled
        if (-not $tlsEnabled -or -not $realityEnabled) {
            throw ("Endpoint '{0}:{1}' is not VLESS Reality." -f $server, $port)
        }
        $publicKey = if ($realityMap.ContainsKey('public_key')) { [string]$realityMap.public_key } else { '' }
        if ([string]::IsNullOrWhiteSpace($publicKey)) {
            throw ("Endpoint '{0}:{1}' is missing the Reality public key." -f $server, $port)
        }
        $utlsMap = if ($tlsMap.ContainsKey('utls')) { ConvertTo-Map -Value $tlsMap.utls } else { @{} }

        [pscustomobject][ordered]@{
            Server           = $server
            Port             = $port
            Remark           = [string](Get-PropertyValue -InputObject $address -Name 'remark')
            TlsEnabled       = $tlsEnabled
            Security         = 'reality'
            ServerName       = if ($tlsMap.ContainsKey('server_name')) { [string]$tlsMap.server_name } else { '' }
            Alpn             = if ($tlsMap.ContainsKey('alpn')) { @($tlsMap.alpn) } else { @() }
            Insecure         = $tlsMap.ContainsKey('insecure') -and [bool]$tlsMap.insecure
            Fingerprint      = if ($utlsMap.ContainsKey('fingerprint')) { [string]$utlsMap.fingerprint } else { '' }
            RealityPublicKey = $publicKey
            RealityShortId   = if ($realityMap.ContainsKey('short_id')) { [string]$realityMap.short_id } else { '' }
        }
    }
)
if (@($endpoints).Count -eq 0) {
    throw 'No VLESS Reality endpoints were extracted.'
}

try {
    $uuidSecure = ConvertTo-SecureString $uuidPlain -AsPlainText -Force
    [pscustomobject][ordered]@{
        PSTypeName    = 'ClashXY.VlessRealityConnection'
        SchemaVersion = 1
        Protocol      = 'vless'
        InboundId     = $inboundId
        InboundTag    = [string](Get-PropertyValue -InputObject $Inbound -Name 'tag')
        ClientId      = $clientId
        ClientName    = $clientName
        Uuid          = $uuidSecure
        UuidPresent   = $true
        Flow          = $flow
        Transport     = $transport
        Endpoints     = $endpoints
    }
}
finally {
    $uuidPlain = $null
}
