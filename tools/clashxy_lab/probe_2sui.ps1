[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUrl,

    [string]$Username,

    [securestring]$Password,

    [securestring]$TwoFactorCode,

    [securestring]$ApiToken,

    [switch]$AllowInsecureHttp,

    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

    [switch]$KeepSession
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PanelBaseUrl {
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [switch]$AllowHttp
    )

    if ($Uri.Scheme -notin @('https', 'http')) {
        throw 'Panel URL must use HTTPS or HTTP.'
    }
    if ($Uri.UserInfo) {
        throw 'Panel URL must not contain credentials.'
    }
    if ($Uri.Query -or $Uri.Fragment) {
        throw 'Panel URL must not contain a query string or fragment.'
    }
    if ($Uri.Scheme -eq 'http' -and -not $AllowHttp) {
        throw 'Plain HTTP is disabled. Use -AllowInsecureHttp only for an explicit development test.'
    }

    $builder = [System.UriBuilder]::new($Uri)
    $path = $builder.Path
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = '/'
    }
    if (-not $path.EndsWith('/')) {
        $path += '/'
    }
    $builder.Path = $path
    $builder.Query = ''
    $builder.Fragment = ''
    return $builder.Uri
}

function ConvertFrom-SecureValue {
    param([securestring]$Value)

    if ($null -eq $Value) {
        return $null
    }
    return [System.Net.NetworkCredential]::new('', $Value).Password
}

function Protect-Message {
    param(
        [AllowNull()]
        [string]$Text,

        [object[]]$Secrets
    )

    if ($null -eq $Text) {
        return ''
    }

    $safe = $Text
    foreach ($secret in $Secrets) {
        $candidate = [string]$secret
        if (-not [string]::IsNullOrEmpty($candidate)) {
            $safe = $safe.Replace($candidate, '<redacted>')
        }
    }

    $safe = $safe -replace '(?i)(token|password|secret|uuid)\s*[:=]\s*[^\s,;]+', '$1=<redacted>'
    if ($safe.Length -gt 200) {
        $safe = $safe.Substring(0, 200) + '…'
    }
    return $safe
}

function Invoke-PanelWebRequest {
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [ValidateSet('GET', 'POST')]
        [string]$Method = 'GET',

        [hashtable]$Headers = @{},

        [hashtable]$Body
    )

    $request = @{
        Uri                = $Uri
        Method             = $Method
        WebSession         = $Session
        Headers            = $Headers
        SkipHttpErrorCheck = $true
        ErrorAction        = 'Stop'
    }
    if ($null -ne $Body) {
        $request.Body = $Body
        $request.ContentType = 'application/x-www-form-urlencoded; charset=UTF-8'
    }

    return Invoke-WebRequest @request
}

function Get-EnvelopeSummary {
    param(
        [Parameter(Mandatory)]
        $Response,

        [object[]]$Secrets
    )

    $contentType = [string]$Response.Headers['Content-Type']
    $summary = [ordered]@{
        HttpStatus  = [int]$Response.StatusCode
        ContentType = $contentType
        IsEnvelope  = $false
        Success     = $null
        Message     = ''
        ObjectType  = $null
        ObjectKeys  = @()
        TwoFa       = $false
    }

    try {
        $data = ([string]$Response.Content) | ConvertFrom-Json -Depth 100
    }
    catch {
        return [pscustomobject]$summary
    }

    $propertyNames = @($data.PSObject.Properties.Name)
    if (-not (($propertyNames -contains 'success') -and ($propertyNames -contains 'msg') -and ($propertyNames -contains 'obj'))) {
        return [pscustomobject]$summary
    }

    $summary.IsEnvelope = $true
    $summary.Success = [bool]$data.success
    $summary.Message = Protect-Message -Text ([string]$data.msg) -Secrets $Secrets

    if ($null -ne $data.obj) {
        $summary.ObjectType = $data.obj.GetType().Name
        $summary.ObjectKeys = @($data.obj.PSObject.Properties.Name | Sort-Object)
        if ($summary.ObjectKeys -contains 'twoFa') {
            $summary.TwoFa = [bool]$data.obj.twoFa
        }
    }

    return [pscustomobject]$summary
}

function Get-CookieSummary {
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory)]
        [uri]$Uri
    )

    return @(
        $Session.Cookies.GetCookies($Uri) |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject]@{
                    Name        = $_.Name
                    Domain      = $_.Domain
                    Path        = $_.Path
                    Secure      = $_.Secure
                    HttpOnly    = $_.HttpOnly
                    SameSite    = if ($_.PSObject.Properties.Name -contains 'SameSite') { [string]$_.SameSite } else { 'Unavailable' }
                    ExpiresUtc  = if ($_.Expires -eq [datetime]::MinValue) { $null } else { $_.Expires.ToUniversalTime().ToString('o') }
                    ValueLength = $_.Value.Length
                }
            }
    )
}

$panelBase = Resolve-PanelBaseUrl -Uri $BaseUrl -AllowHttp:$AllowInsecureHttp
$session = if ($null -eq $WebSession) { [Microsoft.PowerShell.Commands.WebRequestSession]::new() } else { $WebSession }
$steps = [System.Collections.Generic.List[object]]::new()
$passwordPlain = $null
$codePlain = $null
$tokenPlain = $null
$loginSucceeded = $false
$cookiesAfterLogin = @()
$cookiesAfterLogout = @()

try {
    $loginPage = Invoke-PanelWebRequest -Uri ([uri]::new($panelBase, 'login')) -Session $session
    $steps.Add([pscustomobject]@{
        Step   = 'login-page'
        Result = Get-EnvelopeSummary -Response $loginPage -Secrets @($Username)
    })

    $invalidToken = Invoke-PanelWebRequest -Uri ([uri]::new($panelBase, 'apiv2/status?r=sys')) -Session $session
    $steps.Add([pscustomobject]@{
        Step   = 'apiv2-without-token'
        Result = Get-EnvelopeSummary -Response $invalidToken -Secrets @($Username)
    })

    if (-not [string]::IsNullOrWhiteSpace($Username)) {
        if ($null -eq $Password) {
            $Password = Read-Host 'Panel password' -AsSecureString
        }
        $passwordPlain = ConvertFrom-SecureValue -Value $Password
        $secrets = @($Username, $passwordPlain)

        $loginResponse = Invoke-PanelWebRequest `
            -Uri ([uri]::new($panelBase, 'api/login')) `
            -Session $session `
            -Method POST `
            -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } `
            -Body @{ user = $Username; pass = $passwordPlain; code = '' }

        $loginSummary = Get-EnvelopeSummary -Response $loginResponse -Secrets $secrets
        $steps.Add([pscustomobject]@{
            Step   = 'login'
            Result = $loginSummary
        })

        if ($loginSummary.TwoFa) {
            if ($null -eq $TwoFactorCode) {
                $TwoFactorCode = Read-Host 'Two-factor code' -AsSecureString
            }
            $codePlain = ConvertFrom-SecureValue -Value $TwoFactorCode
            $secrets = @($Username, $passwordPlain, $codePlain)

            $twoFaResponse = Invoke-PanelWebRequest `
                -Uri ([uri]::new($panelBase, 'api/login')) `
                -Session $session `
                -Method POST `
                -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } `
                -Body @{ user = $Username; pass = $passwordPlain; code = $codePlain }

            $loginSummary = Get-EnvelopeSummary -Response $twoFaResponse -Secrets $secrets
            $steps.Add([pscustomobject]@{
                Step   = 'login-two-factor'
                Result = $loginSummary
            })
        }

        $loginSucceeded = $loginSummary.IsEnvelope -and $loginSummary.Success
        if ($loginSucceeded) {
            $cookiesAfterLogin = Get-CookieSummary -Session $session -Uri $panelBase

            $tokenList = Invoke-PanelWebRequest -Uri ([uri]::new($panelBase, 'api/tokens')) -Session $session
            $steps.Add([pscustomobject]@{
                Step   = 'session-token-list'
                Result = Get-EnvelopeSummary -Response $tokenList -Secrets @($Username, $passwordPlain, $codePlain)
            })
        }
    }

    if ($null -ne $ApiToken) {
        $tokenPlain = ConvertFrom-SecureValue -Value $ApiToken
        $tokenStatus = Invoke-PanelWebRequest `
            -Uri ([uri]::new($panelBase, 'apiv2/status?r=sys')) `
            -Session $session `
            -Headers @{ Token = $tokenPlain }

        $steps.Add([pscustomobject]@{
            Step   = 'apiv2-with-token'
            Result = Get-EnvelopeSummary -Response $tokenStatus -Secrets @($Username, $passwordPlain, $codePlain, $tokenPlain)
        })
    }

    if ($loginSucceeded -and -not $KeepSession) {
        $logout = Invoke-PanelWebRequest -Uri ([uri]::new($panelBase, 'api/logout')) -Session $session
        $steps.Add([pscustomobject]@{
            Step   = 'logout'
            Result = Get-EnvelopeSummary -Response $logout -Secrets @($Username, $passwordPlain, $codePlain, $tokenPlain)
        })
        $cookiesAfterLogout = Get-CookieSummary -Session $session -Uri $panelBase
    }

    [pscustomobject]@{
        SchemaVersion      = 1
        TestedAtUtc        = [datetime]::UtcNow.ToString('o')
        BaseUrl            = $panelBase.AbsoluteUri
        InsecureHttpOptIn  = [bool]$AllowInsecureHttp
        Steps              = @($steps)
        CookiesAfterLogin  = $cookiesAfterLogin
        CookiesAfterLogout = $cookiesAfterLogout
        SessionRetained    = ($loginSucceeded -and [bool]$KeepSession)
    } | ConvertTo-Json -Depth 12
}
finally {
    $passwordPlain = $null
    $codePlain = $null
    $tokenPlain = $null
}
