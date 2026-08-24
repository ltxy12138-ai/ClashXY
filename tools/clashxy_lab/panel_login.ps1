[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$Username,

    [securestring]$Password,

    [securestring]$TwoFactorCode,

    [switch]$AllowInsecureHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($null -eq $Password) {
    $Password = Read-Host 'Panel password' -AsSecureString
}

$probeParams = @{
    BaseUrl  = $BaseUrl
    Username = $Username
    Password = $Password
}
if ($null -ne $TwoFactorCode) {
    $probeParams.TwoFactorCode = $TwoFactorCode
}
if ($AllowInsecureHttp) {
    $probeParams.AllowInsecureHttp = $true
}

$probeJson = & (Join-Path $PSScriptRoot 'probe_2sui.ps1') @probeParams
$probe = $probeJson | ConvertFrom-Json -Depth 20
$steps = @($probe.Steps)
$initialLogin = $steps | Where-Object Step -eq 'login' | Select-Object -First 1
$twoFactorLogin = $steps | Where-Object Step -eq 'login-two-factor' | Select-Object -First 1
$finalLogin = if ($null -ne $twoFactorLogin) { $twoFactorLogin } else { $initialLogin }
$logout = $steps | Where-Object Step -eq 'logout' | Select-Object -First 1
$cookies = @($probe.CookiesAfterLogin)
$sessionCookie = $cookies | Where-Object Name -eq 's-ui' | Select-Object -First 1

if ($null -eq $finalLogin) {
    throw 'Panel login probe did not return a login result.'
}

[pscustomobject]@{
    SchemaVersion      = 1
    BaseUrl            = $probe.BaseUrl
    Success            = [bool]$finalLogin.Result.Success
    HttpStatus         = [int]$finalLogin.Result.HttpStatus
    Message            = [string]$finalLogin.Result.Message
    TwoFactorRequired  = ($null -ne $initialLogin -and [bool]$initialLogin.Result.TwoFa)
    TwoFactorUsed      = ($null -ne $twoFactorLogin)
    SessionCookie      = $sessionCookie
    LogoutSuccess      = ($null -ne $logout -and [bool]$logout.Result.Success)
}
