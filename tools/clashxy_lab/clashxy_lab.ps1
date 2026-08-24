[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'version', 'panel', 'panel-test', 'device', 'profile', 'mihomo', 'status', 'tun', 'e2e')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [string]$Action,

    [uri]$BaseUrl,

    [string]$Username,

    [securestring]$Password,

    [securestring]$TwoFactorCode,

    [securestring]$ApiToken,

    [ValidateRange(1, 365)]
    [int]$TokenExpiryDays = 1,

    [string]$DeviceName,

    [uint32]$ClientId,

    [uint32]$InboundId,

    [string]$ExpectedClientName,

    [uint32[]]$InboundIds = @(),

    [switch]$SafeSchemaOnly,
    [string]$CorePath,

    [string]$ConfigPath,

    [string]$RuntimeDirectory,

    [string]$StatePath,

    [ValidateRange(1, 60)]
    [int]$ProcessTimeoutSeconds = 10,
    [uri]$ControllerUri,

    [securestring]$ControllerSecret,

    [ValidateRange(1, 30)]
    [int]$ControllerTimeoutSeconds = 5,
    [string]$TunDeviceName,

    [string]$TunIPv4Address,

    [uri]$ConnectivityUri,

    [string]$ExpectedResponseText,

    [ValidateRange(1, 30)]
    [int]$E2ETimeoutSeconds = 10,

    [switch]$AllowInsecureHttp
)
Set-StrictMode -Version Latest
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'ClashXY Lab requires PowerShell 7 or newer. Start PowerShell 7 with pwsh and run the command again.'
}

$ErrorActionPreference = 'Stop'
$commandParameters = @{} + $PSBoundParameters

function Show-Help {
    @'
ClashXY Lab

Usage:
  .\clashxy_lab.ps1 help
  .\clashxy_lab.ps1 version
  .\clashxy_lab.ps1 panel login -BaseUrl https://panel.example.com/app/ -Username admin
  .\clashxy_lab.ps1 panel-test -BaseUrl https://panel.example.com/app/
  .\clashxy_lab.ps1 panel token-test -BaseUrl https://panel.example.com/app/ -Username admin
  .\clashxy_lab.ps1 panel inbounds -BaseUrl https://panel.example.com/app/
  .\clashxy_lab.ps1 panel clients -BaseUrl https://panel.example.com/app/
  .\clashxy_lab.ps1 device create -BaseUrl https://panel.example.com/app/ -InboundIds 1,2
  .\clashxy_lab.ps1 device delete -BaseUrl https://panel.example.com/app/ -ClientId 123

  .\clashxy_lab.ps1 profile inspect-vless -BaseUrl https://panel.example.com/app/ -InboundId 1 -ClientId 2
  .\clashxy_lab.ps1 profile inspect-hysteria2 -BaseUrl https://panel.example.com/app/ -InboundId 1 -ClientId 2
  .\clashxy_lab.ps1 mihomo start -CorePath C:\path\mihomo.exe -ConfigPath C:\path\config.yaml -RuntimeDirectory C:\path\runtime
  .\clashxy_lab.ps1 mihomo stop -RuntimeDirectory C:\path\runtime
  .\clashxy_lab.ps1 status -ControllerUri http://127.0.0.1:9090
  .\clashxy_lab.ps1 tun status -ControllerUri http://127.0.0.1:9090 -TunDeviceName ClashXY
  .\clashxy_lab.ps1 e2e run -CorePath C:\path\mihomo.exe -BaseUrl https://panel.example.com/app/ -Username admin -InboundId 1 -ConnectivityUri https://example.com/ -RuntimeDirectory C:\path\e2e-runtime
Credentials are accepted as SecureString values. When -Password or a required
-TwoFactorCode is omitted, the CLI prompts without echoing the value.

The CLI prints only redacted structural summaries. It never prints response
objects, password values, token values, TOTP values, or cookie values.
'@
}

function Get-CommonPanelParams {
    if ($null -eq $BaseUrl) {
        throw 'Panel command requires -BaseUrl.'
    }

    $params = @{
        BaseUrl = $BaseUrl
    }
    foreach ($name in @('Username', 'Password', 'TwoFactorCode', 'ApiToken')) {
        if ($commandParameters.ContainsKey($name)) {
            $params[$name] = $commandParameters[$name]
        }
    }
    if ($AllowInsecureHttp) {
        $params.AllowInsecureHttp = $true
    }
    return $params
}

switch ($Command) {
    'version' {
        'ClashXY Lab 0.18.0-dev'
    }
    'panel' {
        $panelParams = Get-CommonPanelParams
        switch ($Action) {
            'login' {
                if ([string]::IsNullOrWhiteSpace($Username)) {
                    throw 'Panel login requires -Username.'
                }
                $panelParams.Remove('ApiToken')
                $result = & (Join-Path $PSScriptRoot 'panel_login.ps1') @panelParams
                $result | ConvertTo-Json -Depth 10
                if (-not $result.Success) {
                    throw ('Panel login failed: ' + $result.Message.Trim())
                }
            }
            'token-test' {
                if ([string]::IsNullOrWhiteSpace($Username)) {
                    throw 'Panel token-test requires -Username.'
                }
                $panelParams.Remove('ApiToken')
                $panelParams.TokenExpiryDays = $TokenExpiryDays
                $result = & (Join-Path $PSScriptRoot 'panel_token_test.ps1') @panelParams
                $result | ConvertTo-Json -Depth 10
                if (-not $result.Success) {
                    throw 'Panel Token experiment failed or cleanup was incomplete.'
                }
            }
            'inbounds' {
                foreach ($name in @('Username', 'Password', 'TwoFactorCode')) {
                    $panelParams.Remove($name)
                }
                $result = & (Join-Path $PSScriptRoot 'panel_inbounds.ps1') @panelParams
                $result | ConvertTo-Json -Depth 10
            }
            'clients' {
                foreach ($name in @('Username', 'Password', 'TwoFactorCode')) {
                    $panelParams.Remove($name)
                }
                $result = & (Join-Path $PSScriptRoot 'panel_clients.ps1') @panelParams
                $result | ConvertTo-Json -Depth 10
            }
            default {
                throw 'Supported panel actions: login, token-test, inbounds, clients.'
            }
        }
    }
    'device' {
        if ($null -eq $BaseUrl) {
            throw 'Device command requires -BaseUrl.'
        }
        $deviceParams = @{
            BaseUrl = $BaseUrl
        }
        if ($commandParameters.ContainsKey('ApiToken')) {
            $deviceParams.ApiToken = $ApiToken
        }
        if ($AllowInsecureHttp) {
            $deviceParams.AllowInsecureHttp = $true
        }

        switch ($Action) {
            'create' {
                $deviceParams.InboundIds = @($InboundIds)
                if ($commandParameters.ContainsKey('DeviceName')) {
                    $deviceParams.DeviceName = $DeviceName
                }
                if ($SafeSchemaOnly) {
                    $deviceParams.SafeSchemaOnly = $true
                }
                $result = & (Join-Path $PSScriptRoot 'device_create.ps1') @deviceParams
            }
            'delete' {
                if (-not $commandParameters.ContainsKey('ClientId') -or $ClientId -eq 0) {
                    throw 'device delete requires -ClientId.'
                }
                $deviceParams.ClientId = $ClientId
                if ($commandParameters.ContainsKey('ExpectedClientName')) {
                    $deviceParams.ExpectedClientName = $ExpectedClientName
                }
                $result = & (Join-Path $PSScriptRoot 'device_delete.ps1') @deviceParams
            }
            default {
                throw 'Supported device actions: create, delete.'
            }
        }
        $result | ConvertTo-Json -Depth 10
    }
    'profile' {
        if ($Action -notin @('inspect-vless', 'inspect-hysteria2')) {
            throw 'Supported profile actions: inspect-vless, inspect-hysteria2.'
        }
        if ($null -eq $BaseUrl) {
            throw 'Profile command requires -BaseUrl.'
        }
        if (-not $commandParameters.ContainsKey('InboundId') -or $InboundId -eq 0) {
            throw "profile $Action requires -InboundId."
        }
        if (-not $commandParameters.ContainsKey('ClientId') -or $ClientId -eq 0) {
            throw "profile $Action requires -ClientId."
        }
        $profileParams = @{
            BaseUrl   = $BaseUrl
            InboundId = $InboundId
            ClientId  = $ClientId
        }
        if ($commandParameters.ContainsKey('ApiToken')) {
            $profileParams.ApiToken = $ApiToken
        }
        if ($AllowInsecureHttp) {
            $profileParams.AllowInsecureHttp = $true
        }
        $profileScript = if ($Action -eq 'inspect-vless') {
            'profile_vless_inspect.ps1'
        }
        else {
            'profile_hysteria2_inspect.ps1'
        }
        $result = & (Join-Path $PSScriptRoot $profileScript) @profileParams
        $result | ConvertTo-Json -Depth 15
    }
    'mihomo' {
        if ([string]::IsNullOrWhiteSpace($RuntimeDirectory)) {
            throw "mihomo $Action requires -RuntimeDirectory."
        }
        $processParams = @{
            RuntimeDirectory = $RuntimeDirectory
        }
        if ($commandParameters.ContainsKey('StatePath')) {
            $processParams.StatePath = $StatePath
        }

        switch ($Action) {
            'start' {
                if ([string]::IsNullOrWhiteSpace($CorePath)) {
                    throw 'mihomo start requires -CorePath.'
                }
                if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
                    throw 'mihomo start requires -ConfigPath.'
                }
                $processParams.CorePath = $CorePath
                $processParams.ConfigPath = $ConfigPath
                $processParams.StartupTimeoutSeconds = $ProcessTimeoutSeconds
                $result = & (Join-Path $PSScriptRoot 'mihomo_start.ps1') @processParams
            }
            'stop' {
                $processParams.ShutdownTimeoutSeconds = $ProcessTimeoutSeconds
                $result = & (Join-Path $PSScriptRoot 'mihomo_stop.ps1') @processParams
            }
            default {
                throw 'Supported mihomo actions: start, stop.'
            }
        }
        $result | ConvertTo-Json -Depth 10
    }
    'status' {
        if ($null -eq $ControllerUri) {
            throw 'status requires -ControllerUri.'
        }
        $statusSecret = if ($commandParameters.ContainsKey('ControllerSecret')) {
            $ControllerSecret
        }
        else {
            Read-Host 'Mihomo Controller Secret' -AsSecureString
        }
        $result = & (Join-Path $PSScriptRoot 'controller_status.ps1') -ControllerUri $ControllerUri -ControllerSecret $statusSecret -TimeoutSeconds $ControllerTimeoutSeconds
        $result | ConvertTo-Json -Depth 10
    }
    'tun' {
        if ($Action -ne 'status') {
            throw 'Supported tun action: status.'
        }
        if ($null -eq $ControllerUri) {
            throw 'tun status requires -ControllerUri.'
        }
        if ([string]::IsNullOrWhiteSpace($TunDeviceName)) {
            throw 'tun status requires -TunDeviceName.'
        }
        $tunSecret = if ($commandParameters.ContainsKey('ControllerSecret')) {
            $ControllerSecret
        }
        else {
            Read-Host 'Mihomo Controller Secret' -AsSecureString
        }
        $result = & (Join-Path $PSScriptRoot 'tun_status.ps1') -ControllerUri $ControllerUri -ControllerSecret $tunSecret -TunDeviceName $TunDeviceName -TimeoutSeconds $ControllerTimeoutSeconds
        $result | ConvertTo-Json -Depth 10
    }
    'e2e' {
        if ($Action -ne 'run') {
            throw 'Supported e2e action: run.'
        }
        if ($null -eq $BaseUrl) {
            throw 'e2e run requires -BaseUrl.'
        }
        if ([string]::IsNullOrWhiteSpace($Username)) {
            throw 'e2e run requires -Username.'
        }
        if (-not $commandParameters.ContainsKey('InboundId') -or $InboundId -eq 0) {
            throw 'e2e run requires -InboundId.'
        }
        if ([string]::IsNullOrWhiteSpace($CorePath)) {
            throw 'e2e run requires -CorePath.'
        }
        if ([string]::IsNullOrWhiteSpace($RuntimeDirectory)) {
            throw 'e2e run requires -RuntimeDirectory.'
        }
        if ($null -eq $ConnectivityUri) {
            throw 'e2e run requires -ConnectivityUri.'
        }
        $e2eParams = @{
            CorePath         = $CorePath
            BaseUrl          = $BaseUrl
            Username         = $Username
            InboundId        = $InboundId
            ConnectivityUri  = $ConnectivityUri
            RuntimeDirectory = $RuntimeDirectory
            TimeoutSeconds   = $E2ETimeoutSeconds
        }
        foreach ($name in @('Password', 'TwoFactorCode', 'TunDeviceName', 'TunIPv4Address', 'ExpectedResponseText')) {
            if ($commandParameters.ContainsKey($name)) {
                $e2eParams[$name] = $commandParameters[$name]
            }
        }
        if ($AllowInsecureHttp) {
            $e2eParams.AllowInsecureHttp = $true
        }
        $result = & (Join-Path $PSScriptRoot 'e2e_lab.ps1') @e2eParams
        $result | ConvertTo-Json -Depth 10
    }
    'panel-test' {
        $probeParams = Get-CommonPanelParams
        & (Join-Path $PSScriptRoot 'probe_2sui.ps1') @probeParams
    }
    default {
        Show-Help
    }
}
