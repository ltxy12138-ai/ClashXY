[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$ControllerUri,

    [Parameter(Mandatory)]
    [securestring]$ControllerSecret,

    [Parameter(Mandatory)]
    [string]$TunDeviceName,

    [ValidateRange(1, 30)]
    [int]$TimeoutSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not [System.OperatingSystem]::IsWindows()) {
    throw 'TUN status requires Windows.'
}
if ($TunDeviceName -notmatch '^[A-Za-z][A-Za-z0-9-]{0,30}$') {
    throw 'TunDeviceName has an invalid format.'
}

$controllerHealth = & (Join-Path $PSScriptRoot 'controller_status.ps1') -ControllerUri $ControllerUri -ControllerSecret $ControllerSecret -TimeoutSeconds $TimeoutSeconds
$secretPlain = [System.Net.NetworkCredential]::new('', $ControllerSecret).Password
$baseUri = $ControllerUri.AbsoluteUri.TrimEnd('/')
$headers = @{
    Authorization = 'Bearer ' + $secretPlain
    Accept        = 'application/json'
}

try {
    try {
        $response = Invoke-WebRequest -Uri ([uri]($baseUri + '/configs')) -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -SkipHttpErrorCheck
    }
    catch {
        throw ('Mihomo controller config request failed: ' + $_.Exception.Message)
    }
    if ([int]$response.StatusCode -ne 200) {
        throw ('Mihomo controller config request returned HTTP status ' + [int]$response.StatusCode + '.')
    }
    try {
        $body = $response.Content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw 'Mihomo controller configs response is invalid JSON.'
    }
    if ($null -eq $body.PSObject.Properties['tun'] -or $null -eq $body.tun) {
        throw 'Mihomo controller configs response does not contain TUN state.'
    }
    $tun = $body.tun
    if ($null -eq $tun.PSObject.Properties['enable'] -or -not [bool]$tun.enable) {
        throw 'Mihomo controller reports TUN disabled.'
    }
    if ($null -eq $tun.PSObject.Properties['device'] -or [string]$tun.device -cne $TunDeviceName) {
        throw 'Mihomo controller TUN device does not match TunDeviceName.'
    }

    $adapters = @(Get-NetAdapter -Name $TunDeviceName -ErrorAction SilentlyContinue)
    if ($adapters.Count -ne 1) {
        throw 'Expected exactly one Windows TUN adapter with TunDeviceName.'
    }
    $adapter = $adapters[0]
    if ([string]$adapter.Status -ne 'Up') {
        throw 'Windows TUN adapter is not Up.'
    }

    [pscustomobject][ordered]@{
        SchemaVersion     = 1
        Healthy           = $true
        ControllerHealthy = [bool]$controllerHealth.Healthy
        ControllerVersion = [string]$controllerHealth.Version
        TunEnabled        = $true
        TunStack          = [string]$tun.stack
        TunDeviceName     = $TunDeviceName
        AutoRoute         = if ($null -ne $tun.PSObject.Properties['auto-route']) { [bool]$tun.'auto-route' } else { $false }
        StrictRoute       = if ($null -ne $tun.PSObject.Properties['strict-route']) { [bool]$tun.'strict-route' } else { $false }
        AdapterStatus     = [string]$adapter.Status
        InterfaceIndex    = [int]$adapter.ifIndex
        InterfaceType     = [string]$adapter.InterfaceDescription
        CheckedAtUtc      = [DateTime]::UtcNow.ToString('O')
    }
}
finally {
    $headers.Clear()
    $headers = $null
    $secretPlain = $null
}
