[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$ControllerUri,

    [Parameter(Mandatory)]
    [securestring]$ControllerSecret,

    [ValidateRange(1, 30)]
    [int]$TimeoutSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsLoopbackHost {
    param([Parameter(Mandatory)][string]$HostName)

    if ($HostName.Equals('localhost', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $address = $null
    if ([System.Net.IPAddress]::TryParse($HostName, [ref]$address)) {
        return [System.Net.IPAddress]::IsLoopback($address)
    }
    return $false
}

if (-not $ControllerUri.IsAbsoluteUri) {
    throw 'ControllerUri must be absolute.'
}
if ($ControllerUri.Scheme -notin @('http', 'https')) {
    throw 'ControllerUri must use http or https.'
}
if (-not [string]::IsNullOrEmpty($ControllerUri.UserInfo) -or
    -not [string]::IsNullOrEmpty($ControllerUri.Query) -or
    -not [string]::IsNullOrEmpty($ControllerUri.Fragment)) {
    throw 'ControllerUri must not contain user info, query, or fragment.'
}
if ($ControllerUri.AbsolutePath -notin @('', '/')) {
    throw 'ControllerUri must point to the controller root.'
}
if ($ControllerUri.Scheme -eq 'http' -and -not (Test-IsLoopbackHost -HostName $ControllerUri.Host)) {
    throw 'Plain HTTP ControllerUri must use a loopback host.'
}

$secretPlain = [System.Net.NetworkCredential]::new('', $ControllerSecret).Password
if ([string]::IsNullOrEmpty($secretPlain)) {
    throw 'ControllerSecret must not be empty.'
}

$baseUri = $ControllerUri.AbsoluteUri.TrimEnd('/')
$versionUri = [uri]($baseUri + '/version')
$headers = @{
    Authorization = 'Bearer ' + $secretPlain
    Accept        = 'application/json'
}

try {
    try {
        $response = Invoke-WebRequest -Uri $versionUri -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -SkipHttpErrorCheck
    }
    catch {
        throw ('Mihomo controller request failed: ' + $_.Exception.Message)
    }

    $statusCode = [int]$response.StatusCode
    if ($statusCode -ne 200) {
        throw ('Mihomo controller returned HTTP status ' + $statusCode + '.')
    }
    try {
        $body = $response.Content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw 'Mihomo controller returned invalid JSON.'
    }
    if ($null -eq $body.PSObject.Properties['meta'] -or
        $null -eq $body.PSObject.Properties['version'] -or
        [string]::IsNullOrWhiteSpace([string]$body.version)) {
        throw 'Mihomo controller version response is incomplete.'
    }

    [pscustomobject][ordered]@{
        SchemaVersion = 1
        Healthy       = $true
        StatusCode    = $statusCode
        ControllerUri = $baseUri
        Meta           = [bool]$body.meta
        Version        = [string]$body.version
        CheckedAtUtc   = [DateTime]::UtcNow.ToString('O')
    }
}
finally {
    $headers.Clear()
    $headers = $null
    $secretPlain = $null
}
