[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [object]$Connection,

    [ValidateRange(0, 2147483647)]
    [int]$EndpointIndex = 0,

    [string]$Name,

    [switch]$AllowInsecurePinnedCertificate
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

function Convert-ServerPorts {
    param([object[]]$ServerPorts)

    $normalized = @(
        foreach ($value in @($ServerPorts)) {
            $text = [string]$value
            if ([string]::IsNullOrWhiteSpace($text)) {
                continue
            }

            $match = [regex]::Match($text, '^(?<start>\d+)(?:(?<separator>[:-])(?<end>\d+))?$')
            if (-not $match.Success) {
                throw "Invalid Hysteria2 server port entry '$text'."
            }
            $start = [int]$match.Groups['start'].Value
            $end = if ($match.Groups['end'].Success) { [int]$match.Groups['end'].Value } else { $start }
            if ($start -lt 1 -or $start -gt 65535 -or $end -lt 1 -or $end -gt 65535 -or $start -gt $end) {
                throw "Invalid Hysteria2 server port entry '$text'."
            }
            if ($start -eq $end) {
                [string]$start
            }
            else {
                "$start-$end"
            }
        }
    )
    return ($normalized -join ',')
}

if ([string](Get-PropertyValue -InputObject $Connection -PropertyName 'Protocol') -cne 'hysteria2') {
    throw 'Expected a Hysteria2 connection model.'
}
$password = Get-PropertyValue -InputObject $Connection -PropertyName 'Password'
if ($password -isnot [securestring]) {
    throw 'Hysteria2 connection password must be a SecureString.'
}

$endpoints = @(Get-PropertyValue -InputObject $Connection -PropertyName 'Endpoints')
if ($endpoints.Count -eq 0 -or $EndpointIndex -ge $endpoints.Count) {
    throw "EndpointIndex $EndpointIndex is outside the available endpoint range."
}
$endpoint = $endpoints[$EndpointIndex]
$server = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'Server')
$port = [int](Get-PropertyValue -InputObject $endpoint -PropertyName 'Port')
if ([string]::IsNullOrWhiteSpace($server) -or $port -le 0 -or $port -gt 65535) {
    throw 'Hysteria2 Profile requires a valid server and port.'
}
if ([string](Get-PropertyValue -InputObject $endpoint -PropertyName 'Security') -cne 'tls') {
    throw 'Hysteria2 Profile endpoint must use standard TLS.'
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    $clientPart = [string](Get-PropertyValue -InputObject $Connection -PropertyName 'ClientName')
    $tagPart = [string](Get-PropertyValue -InputObject $Connection -PropertyName 'InboundTag')
    $Name = (($clientPart, $tagPart, ($EndpointIndex + 1)) -join '-') -replace '[^\p{L}\p{N}._-]+', '-'
    $Name = $Name.Trim('-')
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "hysteria2-$($EndpointIndex + 1)"
    }
    if ($Name.Length -gt 80) {
        $Name = $Name.Substring(0, 80)
    }
}

$warnings = @()
$ignoredSourceFields = @()
$sourceInsecure = [bool](Get-PropertyValue -InputObject $endpoint -PropertyName 'Insecure')
$certificatePins = @(Get-PropertyValue -InputObject $endpoint -PropertyName 'CertificatePublicKeySha256Pins')
$certificatePins = @($certificatePins | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
$skipCertificateVerify = $sourceInsecure
$tlsPinMode = if ($sourceInsecure) { 'source-skip-cert-verify' } else { 'ca-validation' }

if ($certificatePins.Count -gt 0) {
    if ($sourceInsecure) {
        $warnings += '2S-UI SPKI pins are not representable in Mihomo; source already enables insecure TLS verification.'
        $tlsPinMode = 'source-skip-cert-verify'
    }
    elseif ($AllowInsecurePinnedCertificate) {
        $skipCertificateVerify = $true
        $warnings += 'Security downgrade: 2S-UI SPKI pins were replaced by skip-cert-verify=true.'
        $tlsPinMode = 'explicit-insecure-pin-downgrade'
    }
    else {
        throw '2S-UI certificate_public_key_sha256 SPKI pins cannot be mapped to Mihomo certificate fingerprint. Use -AllowInsecurePinnedCertificate only as an explicit security downgrade.'
    }
}

$sourceFingerprint = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'Fingerprint')
if (-not [string]::IsNullOrWhiteSpace($sourceFingerprint)) {
    $ignoredSourceFields += 'utls.fingerprint'
}

$fields = [ordered]@{
    name               = $Name
    type               = 'hysteria2'
    server             = $server
    port               = $port
    password           = $password
    'skip-cert-verify' = $skipCertificateVerify
}

$serverPorts = Convert-ServerPorts -ServerPorts @(Get-PropertyValue -InputObject $Connection -PropertyName 'ServerPorts')
if (-not [string]::IsNullOrWhiteSpace($serverPorts)) {
    $fields.ports = $serverPorts
}

$clientUpMbps = Get-PropertyValue -InputObject $Connection -PropertyName 'ClientUpMbps'
if ($null -ne $clientUpMbps -and [int]$clientUpMbps -gt 0) {
    $fields.up = "$([int]$clientUpMbps) Mbps"
}
$clientDownMbps = Get-PropertyValue -InputObject $Connection -PropertyName 'ClientDownMbps'
if ($null -ne $clientDownMbps -and [int]$clientDownMbps -gt 0) {
    $fields.down = "$([int]$clientDownMbps) Mbps"
}

$obfsType = [string](Get-PropertyValue -InputObject $Connection -PropertyName 'ObfsType')
$obfsPassword = Get-PropertyValue -InputObject $Connection -PropertyName 'ObfsPassword'
if (-not [string]::IsNullOrWhiteSpace($obfsType)) {
    if ($obfsType -cne 'salamander') {
        throw "Unsupported 2S-UI Hysteria2 obfs type '$obfsType'."
    }
    if ($obfsPassword -isnot [securestring]) {
        throw 'Hysteria2 obfs password must be a SecureString when obfs is enabled.'
    }
    $fields.obfs = $obfsType
    $fields['obfs-password'] = $obfsPassword
}

$sni = [string](Get-PropertyValue -InputObject $endpoint -PropertyName 'ServerName')
if (-not [string]::IsNullOrWhiteSpace($sni)) {
    $fields.sni = $sni
}
$alpn = @(Get-PropertyValue -InputObject $endpoint -PropertyName 'Alpn')
if ($alpn.Count -gt 0) {
    $fields.alpn = @($alpn | ForEach-Object { [string]$_ })
}

[pscustomobject][ordered]@{
    PSTypeName          = 'ClashXY.ProxyProfile'
    SchemaVersion       = 1
    Protocol            = 'hysteria2'
    SourceInboundId     = [uint](Get-PropertyValue -InputObject $Connection -PropertyName 'InboundId')
    SourceClientId      = [uint](Get-PropertyValue -InputObject $Connection -PropertyName 'ClientId')
    SourceEndpointIndex = $EndpointIndex
    SensitiveFieldNames = @('password', 'obfs-password')
    TlsPinMode          = $tlsPinMode
    SecurityWarnings    = @($warnings)
    IgnoredSourceFields = @($ignoredSourceFields)
    Fields              = $fields
}
