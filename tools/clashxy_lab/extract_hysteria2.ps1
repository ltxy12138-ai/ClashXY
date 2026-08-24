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

function Get-OptionalInt {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $value = Get-PropertyValue -InputObject $InputObject -Name $Name
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        return $null
    }
    $number = [int]$value
    if ($number -lt 0) {
        throw "$Name must not be negative."
    }
    return $number
}

$inboundType = [string](Get-PropertyValue -InputObject $Inbound -Name 'type')
if ($inboundType -cne 'hysteria2') {
    throw "Expected a hysteria2 Inbound, received '$inboundType'."
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
$hysteria2Config = Get-PropertyValue -InputObject $config -Name 'hysteria2'
if ($null -eq $hysteria2Config) {
    throw 'Client config.hysteria2 is missing.'
}
$passwordPlain = [string](Get-PropertyValue -InputObject $hysteria2Config -Name 'password')
if ([string]::IsNullOrWhiteSpace($passwordPlain)) {
    throw 'Client config.hysteria2.password is missing.'
}

$outJson = ConvertTo-JsonObject -Value (Get-PropertyValue -InputObject $Inbound -Name 'out_json') -FieldName 'inbound.out_json'
if ($null -eq $outJson) {
    throw 'Inbound out_json is missing.'
}
if ([string](Get-PropertyValue -InputObject $outJson -Name 'type') -cne 'hysteria2') {
    throw 'Inbound out_json is not a hysteria2 client configuration.'
}

# 2S-UI swaps the server's up/down limits while building out_json. These are
# therefore already expressed from the client's point of view.
$clientUpMbps = Get-OptionalInt -InputObject $outJson -Name 'up_mbps'
$clientDownMbps = Get-OptionalInt -InputObject $outJson -Name 'down_mbps'
$serverPorts = @(
    @(Get-PropertyValue -InputObject $outJson -Name 'server_ports') |
        Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) } |
        ForEach-Object { [string]$_ }
)

$obfsMap = ConvertTo-Map -Value (Get-PropertyValue -InputObject $outJson -Name 'obfs')
$obfsType = if ($obfsMap.ContainsKey('type')) { [string]$obfsMap.type } else { '' }
$obfsPasswordPlain = if ($obfsMap.ContainsKey('password')) { [string]$obfsMap.password } else { '' }
if (-not [string]::IsNullOrWhiteSpace($obfsType) -and $obfsType -cne 'salamander') {
    throw "Unsupported Hysteria2 obfs type '$obfsType'."
}
if (-not [string]::IsNullOrWhiteSpace($obfsType) -and [string]::IsNullOrWhiteSpace($obfsPasswordPlain)) {
    throw 'Hysteria2 obfs is enabled but its password is missing.'
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
            throw 'Hysteria2 endpoint requires a non-empty server and a port from 1 to 65535.'
        }

        $addressTlsValue = Get-PropertyValue -InputObject $address -Name 'tls'
        $tlsMap = if ($null -eq $addressTlsValue) {
            Merge-Map -Base $baseTlsMap -Override @{}
        }
        else {
            Merge-Map -Base $baseTlsMap -Override (ConvertTo-Map -Value $addressTlsValue)
        }
        $tlsEnabled = $tlsMap.ContainsKey('enabled') -and [bool]$tlsMap.enabled
        if (-not $tlsEnabled) {
            throw ("Endpoint '{0}:{1}' does not enable TLS." -f $server, $port)
        }
        $realityMap = if ($tlsMap.ContainsKey('reality')) { ConvertTo-Map -Value $tlsMap.reality } else { @{} }
        if ($realityMap.ContainsKey('enabled') -and [bool]$realityMap.enabled) {
            throw ("Endpoint '{0}:{1}' enables Reality, which is unsupported for the Hysteria2 profile path." -f $server, $port)
        }
        $utlsMap = if ($tlsMap.ContainsKey('utls')) { ConvertTo-Map -Value $tlsMap.utls } else { @{} }
        $certificatePins = @(
            if ($tlsMap.ContainsKey('certificate_public_key_sha256')) {
                @($tlsMap.certificate_public_key_sha256) |
                    Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) } |
                    ForEach-Object { [string]$_ }
            }
        )

        [pscustomobject][ordered]@{
            Server                         = $server
            Port                           = $port
            Remark                         = [string](Get-PropertyValue -InputObject $address -Name 'remark')
            TlsEnabled                     = $true
            Security                       = 'tls'
            ServerName                     = if ($tlsMap.ContainsKey('server_name')) { [string]$tlsMap.server_name } else { '' }
            Alpn                           = if ($tlsMap.ContainsKey('alpn')) { @($tlsMap.alpn) } else { @() }
            Insecure                       = $tlsMap.ContainsKey('insecure') -and [bool]$tlsMap.insecure
            Fingerprint                    = if ($utlsMap.ContainsKey('fingerprint')) { [string]$utlsMap.fingerprint } else { '' }
            CertificatePublicKeySha256Pins = $certificatePins
        }
    }
)
if (@($endpoints).Count -eq 0) {
    throw 'No Hysteria2 endpoints were extracted.'
}

$tcpFastOpenValue = Get-PropertyValue -InputObject $Inbound -Name 'tcp_fast_open'
$tcpFastOpen = if ($null -eq $tcpFastOpenValue) { $null } else { [bool]$tcpFastOpenValue }

try {
    $passwordSecure = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
    $obfsPasswordSecure = if ([string]::IsNullOrWhiteSpace($obfsPasswordPlain)) {
        $null
    }
    else {
        ConvertTo-SecureString $obfsPasswordPlain -AsPlainText -Force
    }

    [pscustomobject][ordered]@{
        PSTypeName          = 'ClashXY.Hysteria2Connection'
        SchemaVersion       = 1
        Protocol            = 'hysteria2'
        InboundId           = $inboundId
        InboundTag          = [string](Get-PropertyValue -InputObject $Inbound -Name 'tag')
        ClientId            = $clientId
        ClientName          = $clientName
        Password            = $passwordSecure
        PasswordPresent     = $true
        ClientUpMbps        = $clientUpMbps
        ClientDownMbps      = $clientDownMbps
        ServerPorts         = $serverPorts
        TcpFastOpen         = $tcpFastOpen
        ObfsType            = $obfsType
        ObfsPassword        = $obfsPasswordSecure
        ObfsPasswordPresent = -not [string]::IsNullOrWhiteSpace($obfsPasswordPlain)
        Endpoints           = $endpoints
    }
}
finally {
    $passwordPlain = $null
    $obfsPasswordPlain = $null
}
