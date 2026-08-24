[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [object]$Connection,

    [ValidateRange(0, 2147483647)]
    [int]$EndpointIndex = 0,

    [string]$Name
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function ConvertTo-OrderedMap {
    param([AllowNull()][object]$Value)

    $result = [ordered]@{}
    if ($null -eq $Value) {
        return $result
    }

    $source = if ($Value -is [System.Collections.IDictionary]) {
        $Value
    }
    else {
        ($Value | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json -Depth 100 -AsHashtable
    }
    foreach ($key in $source.Keys) {
        $result[[string]$key] = $source[$key]
    }
    return $result
}

function Add-HostHeader {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Headers,

        [object[]]$HostValues,

        [switch]$AsArray
    )

    $hosts = @($HostValues | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($hosts.Count -eq 0 -or $Headers.Contains('Host')) {
        return
    }

    if ($AsArray) {
        $Headers['Host'] = @($hosts | ForEach-Object { [string]$_ })
    }
    else {
        $Headers['Host'] = [string]$hosts[0]
    }
}

if ([string](Get-PropertyValue -InputObject $Connection -PropertyName 'Protocol') -cne 'vless') {
    throw 'Expected a VLESS connection model.'
}
$uuid = Get-PropertyValue -InputObject $Connection -PropertyName 'Uuid'
if ($uuid -isnot [securestring]) {
    throw 'VLESS connection UUID must be a SecureString.'
}

$endpoints = @(Get-PropertyValue -InputObject $Connection -PropertyName 'Endpoints')
if ($endpoints.Count -eq 0 -or $EndpointIndex -ge $endpoints.Count) {
    throw "EndpointIndex $EndpointIndex is outside the available endpoint range."
}
$endpoint = $endpoints[$EndpointIndex]
$server = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'Server')
$port = [int](Get-PropertyValue -InputObject $endpoint -PropertyName 'Port')
$serverName = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'ServerName')
$publicKey = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'RealityPublicKey')
$shortId = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'RealityShortId')
if ([string]::IsNullOrWhiteSpace($server) -or $port -le 0 -or $port -gt 65535) {
    throw 'VLESS Profile requires a valid server and port.'
}
if ([string]::IsNullOrWhiteSpace($serverName)) {
    throw 'VLESS Reality Profile requires servername.'
}
if ([string]::IsNullOrWhiteSpace($publicKey)) {
    throw 'VLESS Reality Profile requires a public key.'
}
if ([string](Get-PropertyValue -InputObject $endpoint -PropertyName 'Security') -cne 'reality') {
    throw 'VLESS Profile endpoint is not Reality.'
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    $clientPart = [string](Get-PropertyValue -InputObject $Connection -PropertyName 'ClientName')
    $tagPart = [string](Get-PropertyValue -InputObject $Connection -PropertyName 'InboundTag')
    $Name = (($clientPart, $tagPart, ($EndpointIndex + 1)) -join '-') -replace '[^\p{L}\p{N}._-]+', '-'
    $Name = $Name.Trim('-')
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "vless-$($EndpointIndex + 1)"
    }
    if ($Name.Length -gt 80) {
        $Name = $Name.Substring(0, 80)
    }
}

$fields = [ordered]@{
    name               = $Name
    type               = 'vless'
    server             = $server
    port               = $port
    uuid               = $uuid
    udp                = $true
    tls                = $true
    servername         = $serverName
    'skip-cert-verify' = [bool](Get-PropertyValue -InputObject $endpoint -PropertyName 'Insecure')
    encryption         = ''
}

$flow = [string](Get-PropertyValue -InputObject $Connection -PropertyName 'Flow')
if (-not [string]::IsNullOrWhiteSpace($flow)) {
    $fields.flow = $flow
}
$alpn = @(Get-PropertyValue -InputObject $endpoint -PropertyName 'Alpn')
if ($alpn.Count -gt 0) {
    $fields.alpn = @($alpn | ForEach-Object { [string]$_ })
}
$fingerprint = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'Fingerprint')
if (-not [string]::IsNullOrWhiteSpace($fingerprint)) {
    $fields['client-fingerprint'] = $fingerprint
}
$fields['reality-opts'] = [ordered]@{
    'public-key' = $publicKey
    'short-id'   = $shortId
}

$transport = Get-PropertyValue -InputObject $Connection -PropertyName 'Transport'
if ($null -eq $transport) {
    throw 'VLESS connection transport is missing.'
}
$transportType = [string](Get-PropertyValue -InputObject $transport -PropertyName 'Type')
if ([string]::IsNullOrWhiteSpace($transportType)) {
    $transportType = 'tcp'
}
$path = [string](Get-PropertyValue -InputObject $transport -PropertyName 'Path')
$hostValues = @(Get-PropertyValue -InputObject $transport -PropertyName 'Host')
$headers = ConvertTo-OrderedMap -Value (Get-PropertyValue -InputObject $transport -PropertyName 'Headers')

switch ($transportType) {
    'tcp' {
        $fields.network = 'tcp'
    }
    'ws' {
        $fields.network = 'ws'
        $wsOptions = [ordered]@{}
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $wsOptions.path = $path
        }
        Add-HostHeader -Headers $headers -HostValues $hostValues
        if ($headers.Count -gt 0) {
            $wsOptions.headers = $headers
        }
        $maxEarlyData = Get-PropertyValue -InputObject $transport -PropertyName 'MaxEarlyData'
        if ($null -ne $maxEarlyData -and [int]$maxEarlyData -gt 0) {
            $wsOptions['max-early-data'] = [int]$maxEarlyData
        }
        $earlyDataHeaderName = [string](Get-PropertyValue -InputObject $transport -PropertyName 'EarlyDataHeaderName')
        if (-not [string]::IsNullOrWhiteSpace($earlyDataHeaderName)) {
            $wsOptions['early-data-header-name'] = $earlyDataHeaderName
        }
        if ($wsOptions.Count -gt 0) {
            $fields['ws-opts'] = $wsOptions
        }
    }
    'http' {
        $fields.network = 'http'
        $httpOptions = [ordered]@{}
        $method = [string](Get-PropertyValue -InputObject $transport -PropertyName 'Method')
        if (-not [string]::IsNullOrWhiteSpace($method)) {
            $httpOptions.method = $method
        }
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $httpOptions.path = @($path)
        }
        Add-HostHeader -Headers $headers -HostValues $hostValues -AsArray
        if ($headers.Count -gt 0) {
            $httpOptions.headers = $headers
        }
        if ($httpOptions.Count -gt 0) {
            $fields['http-opts'] = $httpOptions
        }
    }
    'grpc' {
        $fields.network = 'grpc'
        $grpcOptions = [ordered]@{}
        $serviceName = [string](Get-PropertyValue -InputObject $transport -PropertyName 'ServiceName')
        if (-not [string]::IsNullOrWhiteSpace($serviceName)) {
            $grpcOptions['grpc-service-name'] = $serviceName
        }
        if ($grpcOptions.Count -gt 0) {
            $fields['grpc-opts'] = $grpcOptions
        }
    }
    'httpupgrade' {
        $fields.network = 'ws'
        $wsOptions = [ordered]@{
            'v2ray-http-upgrade' = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $wsOptions.path = $path
        }
        Add-HostHeader -Headers $headers -HostValues $hostValues
        if ($headers.Count -gt 0) {
            $wsOptions.headers = $headers
        }
        $fields['ws-opts'] = $wsOptions
    }
    default {
        throw "2S-UI transport '$transportType' is unsupported by the Mihomo VLESS Mapper."
    }
}

[pscustomobject][ordered]@{
    PSTypeName          = 'ClashXY.ProxyProfile'
    SchemaVersion       = 1
    Protocol            = 'vless'
    SourceInboundId     = [uint](Get-PropertyValue -InputObject $Connection -PropertyName 'InboundId')
    SourceClientId      = [uint](Get-PropertyValue -InputObject $Connection -PropertyName 'ClientId')
    SourceEndpointIndex = $EndpointIndex
    SensitiveFieldNames = @('uuid')
    Fields              = $fields
}
