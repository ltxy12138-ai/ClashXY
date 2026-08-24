[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$Username,

    [securestring]$Password,

    [securestring]$TwoFactorCode,

    [ValidateRange(1, 365)]
    [int]$TokenExpiryDays = 1,

    [switch]$AllowInsecureHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($null -eq $Password) {
    $Password = Read-Host 'Panel password' -AsSecureString
}

$session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$probeParams = @{
    BaseUrl     = $BaseUrl
    Username    = $Username
    Password    = $Password
    WebSession  = $session
    KeepSession = $true
}
if ($null -ne $TwoFactorCode) {
    $probeParams.TwoFactorCode = $TwoFactorCode
}
if ($AllowInsecureHttp) {
    $probeParams.AllowInsecureHttp = $true
}

$probeJson = & (Join-Path $PSScriptRoot 'probe_2sui.ps1') @probeParams
$probe = $probeJson | ConvertFrom-Json -Depth 20
$loginSteps = @($probe.Steps | Where-Object { $_.Step -in @('login', 'login-two-factor') })
$finalLogin = $loginSteps | Select-Object -Last 1
if ($null -eq $finalLogin -or -not $finalLogin.Result.Success -or -not $probe.SessionRetained) {
    $message = if ($null -eq $finalLogin) { 'missing login result' } else { [string]$finalLogin.Result.Message }
    throw ('Token experiment login failed: ' + $message.Trim())
}

$base = [uri]$probe.BaseUrl
$headers = @{ 'X-Requested-With' = 'XMLHttpRequest' }
$description = 'clashxy-lab-' + [datetime]::UtcNow.ToString('yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$tokenValue = $null
$tokenId = $null
$tokenLength = 0
$apiV2Success = $false
$apiV2HttpStatus = 0
$apiV2ObjectKeys = @()
$tokenDeleted = $false
$tokenAbsentAfterDelete = $false
$logoutSuccess = $false

try {
    $create = Invoke-RestMethod `
        -Uri ([uri]::new($base, 'api/addToken')) `
        -Method Post `
        -WebSession $session `
        -Headers $headers `
        -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' `
        -Body @{ desc = $description; expiry = $TokenExpiryDays }

    if (-not $create.success -or [string]::IsNullOrWhiteSpace([string]$create.obj)) {
        throw '2S-UI did not return a newly created API Token.'
    }
    $tokenValue = [string]$create.obj
    $tokenLength = $tokenValue.Length

    $list = Invoke-RestMethod `
        -Uri ([uri]::new($base, 'api/tokens')) `
        -Method Get `
        -WebSession $session `
        -Headers $headers

    if (-not $list.success) {
        throw 'Unable to list API Tokens after creation.'
    }
    $record = @($list.obj) | Where-Object desc -eq $description | Select-Object -First 1
    if ($null -eq $record) {
        throw 'Created API Token was not found by its unique description.'
    }
    $tokenId = [string]$record.id

    $apiResponse = Invoke-WebRequest `
        -Uri ([uri]::new($base, 'apiv2/status?r=sys')) `
        -Method Get `
        -Headers @{ Token = $tokenValue } `
        -SkipHttpErrorCheck

    $apiV2HttpStatus = [int]$apiResponse.StatusCode
    $apiEnvelope = $apiResponse.Content | ConvertFrom-Json -Depth 100
    $apiV2Success = [bool]$apiEnvelope.success
    if ($null -ne $apiEnvelope.obj) {
        $apiV2ObjectKeys = @($apiEnvelope.obj.PSObject.Properties.Name | Sort-Object)
    }
    if (-not $apiV2Success) {
        throw 'API v2 rejected the newly created Token.'
    }
}
finally {
    try {
        if ([string]::IsNullOrWhiteSpace($tokenId)) {
            $cleanupList = Invoke-RestMethod `
                -Uri ([uri]::new($base, 'api/tokens')) `
                -Method Get `
                -WebSession $session `
                -Headers $headers
            if ($cleanupList.success) {
                $cleanupRecord = @($cleanupList.obj) | Where-Object desc -eq $description | Select-Object -First 1
                if ($null -ne $cleanupRecord) {
                    $tokenId = [string]$cleanupRecord.id
                }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($tokenId)) {
            $delete = Invoke-RestMethod `
                -Uri ([uri]::new($base, 'api/deleteToken')) `
                -Method Post `
                -WebSession $session `
                -Headers $headers `
                -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' `
                -Body @{ id = $tokenId }
            $tokenDeleted = [bool]$delete.success
        }

        $verifyList = Invoke-RestMethod `
            -Uri ([uri]::new($base, 'api/tokens')) `
            -Method Get `
            -WebSession $session `
            -Headers $headers
        if ($verifyList.success) {
            $remaining = @(@($verifyList.obj) | Where-Object desc -eq $description)
            $tokenAbsentAfterDelete = $remaining.Count -eq 0
        }
    }
    finally {
        try {
            $logout = Invoke-RestMethod `
                -Uri ([uri]::new($base, 'api/logout')) `
                -Method Get `
                -WebSession $session `
                -Headers $headers
            $logoutSuccess = [bool]$logout.success
        }
        finally {
            $tokenValue = $null
        }
    }
}

[pscustomobject]@{
    SchemaVersion          = 1
    BaseUrl                = $base.AbsoluteUri
    Description            = $description
    ExpiryDays             = $TokenExpiryDays
    TokenLength            = $tokenLength
    ApiV2HttpStatus        = $apiV2HttpStatus
    ApiV2Success           = $apiV2Success
    ApiV2ObjectKeys        = $apiV2ObjectKeys
    TokenDeleted           = $tokenDeleted
    TokenAbsentAfterDelete = $tokenAbsentAfterDelete
    LogoutSuccess          = $logoutSuccess
    Success                = ($apiV2Success -and $tokenDeleted -and $tokenAbsentAfterDelete -and $logoutSuccess)
}
