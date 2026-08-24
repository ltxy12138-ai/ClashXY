[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CorePath,

    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$Username,

    [securestring]$Password,

    [securestring]$TwoFactorCode,

    [Parameter(Mandatory)]
    [ValidateRange(1, 4294967295)]
    [uint]$InboundId,

    [Parameter(Mandatory)]
    [uri]$ConnectivityUri,

    [Parameter(Mandatory)]
    [string]$RuntimeDirectory,

    [securestring]$VlessUuid,

    [string]$TunDeviceName,

    [string]$TunIPv4Address,

    [string]$ExpectedResponseText,

    [ValidateRange(1, 30)]
    [int]$TimeoutSeconds = 10,

    [switch]$AllowInsecureHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function ConvertTo-IPv4Number {
    param([Parameter(Mandatory)][string]$Address)

    $bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    return ([uint32]$bytes[0] -shl 24) -bor ([uint32]$bytes[1] -shl 16) -bor ([uint32]$bytes[2] -shl 8) -bor [uint32]$bytes[3]
}

function Get-FreeTunIPv4Address {
    $existingNumbers = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { ConvertTo-IPv4Number -Address $_.IPAddress })
    $existingRoutes = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DestinationPrefix)

    for ($attempt = 0; $attempt -lt 256; $attempt++) {
        $thirdOctet = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, 256)
        $fourthBase = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, 64) * 4
        $networkText = '198.19.' + $thirdOctet + '.' + $fourthBase
        $addressText = '198.19.' + $thirdOctet + '.' + ($fourthBase + 1)
        $networkNumber = ConvertTo-IPv4Number -Address $networkText
        $occupiedByAddress = @($existingNumbers | Where-Object { ($_ -band [uint32]4294967292) -eq $networkNumber }).Count -gt 0
        $occupiedByRoute = $existingRoutes -contains ($networkText + '/30')
        if (-not $occupiedByAddress -and -not $occupiedByRoute) {
            return $addressText + '/30'
        }
    }
    throw 'Could not find an unused 198.19.0.0/16 TUN /30.'
}

function Protect-E2EText {
    param(
        [AllowNull()][string]$Text,
        [string[]]$SecretValues = @()
    )

    $safe = if ([string]::IsNullOrWhiteSpace($Text)) { 'E2E operation failed.' } else { $Text }
    foreach ($secretValue in @($SecretValues)) {
        if (-not [string]::IsNullOrEmpty($secretValue)) {
            $safe = $safe.Replace($secretValue, '<redacted>')
        }
    }
    $safe = $safe -replace '(?i)(token|password|secret|uuid|private-key)\s*[:=]\s*[^\s,;]+', '$1=<redacted>'
    if ($safe.Length -gt 600) {
        $safe = $safe.Substring(0, 600) + '...'
    }
    return $safe
}

if (-not [System.OperatingSystem]::IsWindows()) {
    throw 'E2E Lab currently requires Windows.'
}
if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    throw 'E2E Lab requires an elevated administrator token for TUN.'
}
if ($null -eq $Password) {
    $Password = Read-Host 'Panel password' -AsSecureString
}
if ($ConnectivityUri.Scheme -notin @('http', 'https') -or $ConnectivityUri.UserInfo) {
    throw 'ConnectivityUri must be an HTTP(S) URI without user info.'
}

$runtimeFullPath = [System.IO.Path]::GetFullPath($RuntimeDirectory)
[void][System.IO.Directory]::CreateDirectory($runtimeFullPath)
$configPath = Join-Path $runtimeFullPath 'clashxy-e2e.yaml'
$statePath = Join-Path $runtimeFullPath 'mihomo-process.json'
if ([System.IO.File]::Exists($statePath)) {
    throw 'E2E RuntimeDirectory already contains Mihomo process state.'
}
if ([string]::IsNullOrWhiteSpace($TunDeviceName)) {
    $TunDeviceName = 'clashxy-e2e-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
}
if ($TunDeviceName -notmatch '^[A-Za-z][A-Za-z0-9-]{0,30}$') {
    throw 'TunDeviceName has an invalid format.'
}
if ($null -ne (Get-NetAdapter -Name $TunDeviceName -ErrorAction SilentlyContinue)) {
    throw 'TunDeviceName already exists.'
}
if ([string]::IsNullOrWhiteSpace($TunIPv4Address)) {
    $TunIPv4Address = Get-FreeTunIPv4Address
}

$session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$panelBase = $null
$tokenDescription = 'clashxy-lab-e2e-' + [datetime]::UtcNow.ToString('yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$tokenPlain = $null
$tokenSecure = $null
$tokenId = $null
$tokenCreated = $false
$clientId = $null
$clientName = $null
$clientCreated = $false
$coreStarted = $false
$primaryError = $null
$cleanupErrors = [System.Collections.Generic.List[string]]::new()
$loginSucceeded = $false
$tokenValidated = $false
$inboundRead = $false
$profileBuilt = $false
$controllerHealthy = $false
$tunHealthy = $false
$connectivitySucceeded = $false
$connectivityStatusCode = 0
$controllerVersion = $null
$clientDeleted = $false
$tokenDeleted = $false
$logoutSucceeded = $false
$vlessUuidPlain = if ($null -ne $VlessUuid) { [System.Net.NetworkCredential]::new('', $VlessUuid).Password } else { $null }

try {
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
    $probe = (& (Join-Path $PSScriptRoot 'probe_2sui.ps1') @probeParams) | ConvertFrom-Json -Depth 30
    $loginSteps = @($probe.Steps | Where-Object { $_.Step -in @('login', 'login-two-factor') })
    $finalLogin = $loginSteps | Select-Object -Last 1
    if ($null -eq $finalLogin -or -not [bool]$finalLogin.Result.Success -or -not [bool]$probe.SessionRetained) {
        throw 'E2E panel login failed.'
    }
    $loginSucceeded = $true
    $panelBase = [uri]$probe.BaseUrl
    $headers = @{ 'X-Requested-With' = 'XMLHttpRequest' }

    $createToken = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'api/addToken')) -Method Post -WebSession $session -Headers $headers -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' -Body @{ desc = $tokenDescription; expiry = 1 }
    if (-not [bool]$createToken.success -or [string]::IsNullOrWhiteSpace([string]$createToken.obj)) {
        throw 'E2E Token creation failed.'
    }
    $tokenPlain = [string]$createToken.obj
    $tokenSecure = ConvertTo-SecureString $tokenPlain -AsPlainText -Force
    $tokenCreated = $true

    $tokenList = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'api/tokens')) -Method Get -WebSession $session -Headers $headers
    $tokenRecord = @($tokenList.obj | Where-Object desc -eq $tokenDescription) | Select-Object -First 1
    if (-not [bool]$tokenList.success -or $null -eq $tokenRecord) {
        throw 'E2E Token was not found after creation.'
    }
    $tokenId = [string]$tokenRecord.id

    $tokenCheck = Invoke-WebRequest -Uri ([uri]::new($panelBase, 'apiv2/status?r=sys')) -Method Get -Headers @{ Token = $tokenPlain } -TimeoutSec $TimeoutSeconds -SkipHttpErrorCheck
    $tokenEnvelope = ([string]$tokenCheck.Content) | ConvertFrom-Json -Depth 30
    if ([int]$tokenCheck.StatusCode -ne 200 -or -not [bool]$tokenEnvelope.success) {
        throw 'E2E Token failed API v2 validation.'
    }
    $tokenValidated = $true

    $inboundCheck = Invoke-WebRequest -Uri ([uri]::new($panelBase, ('apiv2/inbounds?id=' + $InboundId))) -Method Get -Headers @{ Token = $tokenPlain } -TimeoutSec $TimeoutSeconds -SkipHttpErrorCheck
    $inboundEnvelope = ([string]$inboundCheck.Content) | ConvertFrom-Json -Depth 100
    if ([int]$inboundCheck.StatusCode -ne 200 -or -not [bool]$inboundEnvelope.success -or @($inboundEnvelope.obj.inbounds | Where-Object { [uint]$_.id -eq $InboundId }).Count -ne 1) {
        throw 'E2E Inbound lookup failed.'
    }
    $inboundRead = $true

    $createClientParams = @{
        BaseUrl     = $panelBase
        ApiToken    = $tokenSecure
        DeviceName  = 'e2e-windows'
        InboundIds  = @($InboundId)
    }
    if ($null -ne $VlessUuid) {
        $createClientParams.VlessUuid = $VlessUuid
    }
    if ($AllowInsecureHttp) {
        $createClientParams.AllowInsecureHttp = $true
    }
    $clientResult = & (Join-Path $PSScriptRoot 'device_create.ps1') @createClientParams
    if (-not [bool]$clientResult.Created) {
        throw 'E2E Client creation did not report success.'
    }
    $clientId = [uint]$clientResult.Id
    $clientName = [string]$clientResult.Name
    $clientCreated = $true

    $resolveParams = @{
        BaseUrl       = $panelBase
        ApiToken      = $tokenSecure
        InboundId     = $InboundId
        ClientId      = $clientId
        EndpointIndex = 0
        ProfileName   = 'clashxy-e2e-vless'
    }
    if ($AllowInsecureHttp) {
        $resolveParams.AllowInsecureHttp = $true
    }
    $proxyProfile = & (Join-Path $PSScriptRoot 'resolve_vless_reality_profile.ps1') @resolveParams
    if ($null -eq $proxyProfile -or [string]$proxyProfile.Protocol -ne 'vless') {
        throw 'E2E VLESS Reality Profile resolution failed.'
    }
    $profileBuilt = $true

    $mixedPort = Get-FreeTcpPort
    do {
        $controllerPort = Get-FreeTcpPort
    } while ($controllerPort -eq $mixedPort)
    $configDocument = & (Join-Path $PSScriptRoot 'build_mihomo_config.ps1') -ProxyProfiles @($proxyProfile) -MixedPort $mixedPort -ControllerPort $controllerPort -EnableTun -TunStack mixed -TunDevice $TunDeviceName -TunIPv4Address $TunIPv4Address
    $null = & (Join-Path $PSScriptRoot 'write_mihomo_config.ps1') -ConfigDocument $configDocument -OutputPath $configPath

    $startResult = & (Join-Path $PSScriptRoot 'mihomo_start.ps1') -CorePath $CorePath -ConfigPath $configPath -RuntimeDirectory $runtimeFullPath -StatePath $statePath -StartupTimeoutSeconds $TimeoutSeconds
    if (-not [bool]$startResult.Started) {
        throw 'E2E Mihomo start did not report a new process.'
    }
    $coreStarted = $true

    $controllerUri = [uri]('http://127.0.0.1:' + $controllerPort)
    $controllerResult = & (Join-Path $PSScriptRoot 'controller_status.ps1') -ControllerUri $controllerUri -ControllerSecret $configDocument.ControllerSecret -TimeoutSeconds $TimeoutSeconds
    $controllerHealthy = [bool]$controllerResult.Healthy
    $controllerVersion = [string]$controllerResult.Version

    $tunResult = $null
    $lastTunError = $null
    $tunDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $tunProbeTimeout = [Math]::Max(1, [Math]::Min(3, $TimeoutSeconds))
    do {
        try {
            $tunResult = & (Join-Path $PSScriptRoot 'tun_status.ps1') -ControllerUri $controllerUri -ControllerSecret $configDocument.ControllerSecret -TunDeviceName $TunDeviceName -TimeoutSeconds $tunProbeTimeout
            break
        }
        catch {
            $lastTunError = $_.Exception.Message
            Start-Sleep -Milliseconds 200
        }
    } while ([DateTime]::UtcNow -lt $tunDeadline)
    if ($null -eq $tunResult) {
        throw $(if ([string]::IsNullOrWhiteSpace($lastTunError)) { 'Timed out waiting for Mihomo TUN.' } else { $lastTunError })
    }
    $tunHealthy = [bool]$tunResult.Healthy

    $proxyUri = [uri]('http://127.0.0.1:' + $mixedPort)
    $connectivityResponse = Invoke-WebRequest -Uri $ConnectivityUri -Method Get -Proxy $proxyUri -TimeoutSec $TimeoutSeconds -SkipHttpErrorCheck
    $connectivityStatusCode = [int]$connectivityResponse.StatusCode
    if ($connectivityStatusCode -lt 200 -or $connectivityStatusCode -ge 300) {
        throw ('E2E HTTP connectivity returned status ' + $connectivityStatusCode + '.')
    }
    if (-not [string]::IsNullOrEmpty($ExpectedResponseText) -and -not ([string]$connectivityResponse.Content).Contains($ExpectedResponseText, [System.StringComparison]::Ordinal)) {
        throw 'E2E HTTP connectivity response did not contain the expected marker.'
    }
    $connectivitySucceeded = $true
}
catch {
    $primaryError = Protect-E2EText -Text $_.Exception.Message -SecretValues @($tokenPlain, $vlessUuidPlain)
}
finally {
    if ($coreStarted -or [System.IO.File]::Exists($statePath)) {
        try {
            $stopResult = & (Join-Path $PSScriptRoot 'mihomo_stop.ps1') -RuntimeDirectory $runtimeFullPath -StatePath $statePath -ShutdownTimeoutSeconds $TimeoutSeconds
            if (-not [bool]$stopResult.Stopped -and -not [bool]$stopResult.AlreadyStopped) {
                throw 'Mihomo stop returned an incomplete result.'
            }
        }
        catch {
            $cleanupErrors.Add((Protect-E2EText -Text ('Mihomo cleanup: ' + $_.Exception.Message) -SecretValues @($tokenPlain, $vlessUuidPlain)))
        }
    }

    if ($clientCreated -and $null -ne $tokenSecure) {
        try {
            $deleteParams = @{
                BaseUrl            = $panelBase
                ApiToken           = $tokenSecure
                ClientId           = $clientId
                ExpectedClientName = $clientName
            }
            if ($AllowInsecureHttp) {
                $deleteParams.AllowInsecureHttp = $true
            }
            $deleteResult = & (Join-Path $PSScriptRoot 'device_delete.ps1') @deleteParams
            $clientDeleted = [bool]$deleteResult.Deleted -and [bool]$deleteResult.AbsentAfterDelete
            if (-not $clientDeleted) {
                throw 'Client deletion did not verify absence.'
            }
        }
        catch {
            $cleanupErrors.Add((Protect-E2EText -Text ('Client cleanup: ' + $_.Exception.Message) -SecretValues @($tokenPlain, $vlessUuidPlain)))
        }
    }

    if ($tokenCreated -and $loginSucceeded) {
        try {
            if ([string]::IsNullOrWhiteSpace($tokenId)) {
                $cleanupTokenList = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'api/tokens')) -Method Get -WebSession $session -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' }
                $cleanupTokenRecord = @($cleanupTokenList.obj | Where-Object desc -eq $tokenDescription) | Select-Object -First 1
                if ($null -ne $cleanupTokenRecord) {
                    $tokenId = [string]$cleanupTokenRecord.id
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($tokenId)) {
                $deleteToken = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'api/deleteToken')) -Method Post -WebSession $session -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' -Body @{ id = $tokenId }
                if (-not [bool]$deleteToken.success) {
                    throw 'Token delete was rejected.'
                }
            }
            $verifyTokens = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'api/tokens')) -Method Get -WebSession $session -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' }
            $tokenDeleted = [bool]$verifyTokens.success -and @($verifyTokens.obj | Where-Object desc -eq $tokenDescription).Count -eq 0
            if (-not $tokenDeleted) {
                throw 'Token remained after delete.'
            }
        }
        catch {
            $cleanupErrors.Add((Protect-E2EText -Text ('Token cleanup: ' + $_.Exception.Message) -SecretValues @($tokenPlain, $vlessUuidPlain)))
        }
    }

    if ($loginSucceeded) {
        try {
            $logout = Invoke-RestMethod -Uri ([uri]::new($panelBase, 'api/logout')) -Method Get -WebSession $session -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' }
            $logoutSucceeded = [bool]$logout.success
            if (-not $logoutSucceeded) {
                throw 'Panel logout was rejected.'
            }
        }
        catch {
            $cleanupErrors.Add((Protect-E2EText -Text ('Logout cleanup: ' + $_.Exception.Message) -SecretValues @($tokenPlain, $vlessUuidPlain)))
        }
    }

    if ([System.IO.File]::Exists($configPath)) {
        try {
            [System.IO.File]::Delete($configPath)
        }
        catch {
            $cleanupErrors.Add('Config cleanup: unable to delete the E2E config file.')
        }
    }

    $tokenPlain = $null
    $tokenSecure = $null
    $vlessUuidPlain = $null
}

if (-not [string]::IsNullOrWhiteSpace($primaryError) -or $cleanupErrors.Count -gt 0) {
    $messages = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($primaryError)) {
        $messages.Add($primaryError)
    }
    foreach ($cleanupError in $cleanupErrors) {
        $messages.Add($cleanupError)
    }
    throw ($messages -join ' | ')
}

[pscustomobject][ordered]@{
    SchemaVersion          = 1
    Success                = $true
    LoginSucceeded         = $loginSucceeded
    TokenValidated         = $tokenValidated
    InboundRead            = $inboundRead
    ClientCreated          = $clientCreated
    ProfileBuilt           = $profileBuilt
    ControllerHealthy      = $controllerHealthy
    TunHealthy             = $tunHealthy
    ConnectivitySucceeded  = $connectivitySucceeded
    ConnectivityStatusCode = $connectivityStatusCode
    ControllerVersion      = $controllerVersion
    ClientId               = $clientId
    ClientName             = $clientName
    TunDeviceName          = $TunDeviceName
    ClientDeleted          = $clientDeleted
    TokenDeleted           = $tokenDeleted
    LogoutSucceeded        = $logoutSucceeded
    ConfigDeleted          = -not [System.IO.File]::Exists($configPath)
    CompletedAtUtc         = [DateTime]::UtcNow.ToString('O')
}
