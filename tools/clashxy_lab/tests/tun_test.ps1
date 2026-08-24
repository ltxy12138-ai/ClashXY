[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CorePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-TestSecureString {
    param([Parameter(Mandatory)][string]$Value)
    return ConvertTo-SecureString -String $Value -AsPlainText -Force
}

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

function Read-SharedText {
    param([Parameter(Mandatory)][string]$Path)

    if (-not [System.IO.File]::Exists($Path)) {
        return ''
    }
    $stream = [System.IO.FileStream]::new($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = [System.IO.StreamReader]::new($stream)
    try {
        return $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

$labRoot = Split-Path $PSScriptRoot -Parent
$cliPath = Join-Path $labRoot 'clashxy_lab.ps1'

function ConvertTo-IPv4Number {
    param([Parameter(Mandatory)][string]$Address)

    $bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    return ([uint32]$bytes[0] -shl 24) -bor ([uint32]$bytes[1] -shl 16) -bor ([uint32]$bytes[2] -shl 8) -bor [uint32]$bytes[3]
}

function Get-FreeTunAddress {
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
            return [pscustomobject]@{
                Address = $addressText + '/30'
                Ip      = $addressText
                Network = $networkText + '/30'
            }
        }
    }
    throw 'Could not find an unused 198.19.0.0/16 test /30.'
}
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('clashxy-tun-test-' + [guid]::NewGuid().ToString('N'))
$runtimeDirectory = Join-Path $testRoot 'runtime'
$configPath = Join-Path $testRoot 'config.yaml'
$statePath = Join-Path $runtimeDirectory 'mihomo-process.json'
$startedPid = $null
$tunDeviceName = 'clashxy-lab-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$uuidPlain = '0c5849d0-4f40-4f83-9fdc-ec5b5fcac606'
$controllerPlain = 'fixture-tun-controller-secret-32'
$baselineMihomo = @(Get-NetAdapter -Name 'Mihomo' -ErrorAction SilentlyContinue | Select-Object Name, ifIndex)

try {
    if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        throw 'Windows TUN test requires an elevated administrator token.'
    }
    if ($null -ne (Get-NetAdapter -Name $tunDeviceName -ErrorAction SilentlyContinue)) {
        throw 'Unique TUN test device already exists.'
    }

    [void][System.IO.Directory]::CreateDirectory($runtimeDirectory)
    $mixedPort = Get-FreeTcpPort
    do {
        $controllerPort = Get-FreeTcpPort
    } while ($controllerPort -eq $mixedPort)
    $controllerUri = [uri]('http://127.0.0.1:' + $controllerPort)
    $tunAddressSelection = Get-FreeTunAddress

    $profile = [pscustomobject][ordered]@{
        PSTypeName          = 'ClashXY.ProxyProfile'
        Protocol            = 'vless'
        SensitiveFieldNames = @('uuid')
        Fields              = [ordered]@{
            name                 = 'fixture-tun-vless'
            type                 = 'vless'
            server               = 'example.com'
            port                 = 443
            uuid                 = ConvertTo-TestSecureString $uuidPlain
            udp                  = $true
            tls                  = $true
            servername           = 'www.microsoft.com'
            'skip-cert-verify'   = $false
            encryption           = ''
            flow                 = 'xtls-rprx-vision'
            'client-fingerprint' = 'chrome'
            network              = 'tcp'
            'reality-opts'       = [ordered]@{
                'public-key' = 'KAFmF3QKLoP7hAfWQiBX0niiZw3FLKJ5AGborsv_bkw'
                'short-id'   = 'a1b2c3d4'
            }
        }
    }

    $document = & (Join-Path $labRoot 'build_mihomo_config.ps1') -ProxyProfiles @($profile) -ControllerSecret (ConvertTo-TestSecureString $controllerPlain) -MixedPort $mixedPort -ControllerPort $controllerPort -EnableTun -TunStack mixed -TunDevice $tunDeviceName -TunIPv4Address $tunAddressSelection.Address
    if (-not $document.TunEnabled -or $document.TunAutoRoute -or $document.Ast.tun.'strict-route') {
        throw 'TUN test config must be enabled with routing changes disabled.'
    }
    $null = & (Join-Path $labRoot 'write_mihomo_config.ps1') -ConfigDocument $document -OutputPath $configPath

    $startText = @(& $cliPath mihomo start -CorePath $CorePath -ConfigPath $configPath -RuntimeDirectory $runtimeDirectory -StatePath $statePath) -join [Environment]::NewLine
    $startResult = $startText | ConvertFrom-Json -ErrorAction Stop
    if (-not $startResult.Started) {
        throw 'Failed to start Mihomo for TUN test.'
    }
    $startedPid = [int]$startResult.Pid

    $tunStatus = $null
    $lastStatusError = $null
    for ($attempt = 0; $attempt -lt 12 -and $null -eq $tunStatus; $attempt++) {
        try {
            $statusText = @(& $cliPath tun status -ControllerUri $controllerUri -ControllerSecret (ConvertTo-TestSecureString $controllerPlain) -TunDeviceName $tunDeviceName) -join [Environment]::NewLine
            $tunStatus = $statusText | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $lastStatusError = $_.Exception.Message
            Start-Sleep -Milliseconds 250
        }
    }
    if ($null -eq $tunStatus) {
        $diagnosticText = (Read-SharedText -Path (Join-Path $runtimeDirectory 'mihomo.stdout.log')) + [Environment]::NewLine + (Read-SharedText -Path (Join-Path $runtimeDirectory 'mihomo.stderr.log'))
        $safeDiagnostic = $diagnosticText.Replace($uuidPlain, '<redacted>').Replace($controllerPlain, '<redacted>')
        $diagnosticTail = @($safeDiagnostic -split '\r?\n' | Select-Object -Last 20) -join [Environment]::NewLine
        throw ('TUN did not become healthy: ' + $lastStatusError + [Environment]::NewLine + $diagnosticTail)
    }
    if (-not $tunStatus.Healthy -or -not $tunStatus.TunEnabled -or $tunStatus.AutoRoute -or $tunStatus.TunDeviceName -cne $tunDeviceName -or $tunStatus.AdapterStatus -ne 'Up') {
        throw 'TUN status returned unexpected values.'
    }


    $actualTunAddresses = @(Get-NetIPAddress -InterfaceIndex ([int]$tunStatus.InterfaceIndex) -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress)
    if ($actualTunAddresses -notcontains $tunAddressSelection.Ip) {
        throw 'Windows TUN adapter did not receive the isolated test IPv4 address.'
    }
    $globalRoutes = @(Get-NetRoute -InterfaceIndex ([int]$tunStatus.InterfaceIndex) -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -in @('0.0.0.0/0', '::/0', '0.0.0.0/1', '128.0.0.0/1', '::/1', '8000::/1') })
    if ($globalRoutes.Count -ne 0) {
        throw 'Safe TUN test unexpectedly installed a global route.'
    }

    $stopText = @(& $cliPath mihomo stop -RuntimeDirectory $runtimeDirectory -StatePath $statePath) -join [Environment]::NewLine
    $stopResult = $stopText | ConvertFrom-Json -ErrorAction Stop
    if (-not $stopResult.Stopped -or $stopResult.Pid -ne $startedPid) {
        throw 'Failed to stop Mihomo after TUN test.'
    }
    $startedPid = $null

    $adapterRemoved = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if ($null -eq (Get-NetAdapter -Name $tunDeviceName -ErrorAction SilentlyContinue)) {
            $adapterRemoved = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $adapterRemoved) {
        throw 'Test TUN adapter remained after Mihomo stopped.'
    }

    foreach ($baseline in $baselineMihomo) {
        $current = Get-NetAdapter -Name $baseline.Name -ErrorAction SilentlyContinue
        if ($null -eq $current -or [int]$current.ifIndex -ne [int]$baseline.ifIndex) {
            throw 'Pre-existing Mihomo adapter changed during the isolated TUN test.'
        }
    }

    $stdoutPath = Join-Path $runtimeDirectory 'mihomo.stdout.log'
    $stderrPath = Join-Path $runtimeDirectory 'mihomo.stderr.log'
    $logs = ''
    if ([System.IO.File]::Exists($stdoutPath)) { $logs += [System.IO.File]::ReadAllText($stdoutPath) }
    if ([System.IO.File]::Exists($stderrPath)) { $logs += [System.IO.File]::ReadAllText($stderrPath) }
    $observableText = $startText + $statusText + $stopText + $logs
    foreach ($secretValue in @($uuidPlain, $controllerPlain)) {
        if ($observableText.Contains($secretValue, [System.StringComparison]::Ordinal)) {
            throw 'TUN test output leaked a fixture secret.'
        }
    }

    'PASS: elevated Windows TUN adapter up, controller config verified, no global route, isolated device cleanup, and redaction'
}
finally {
    if ($null -ne $startedPid) {
        $candidate = Get-Process -Id $startedPid -ErrorAction SilentlyContinue
        if ($null -ne $candidate -and [System.IO.Path]::GetFullPath($candidate.Path).Equals([System.IO.Path]::GetFullPath($CorePath), [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-Process -Id $startedPid -Force -ErrorAction SilentlyContinue
            [void]$candidate.WaitForExit(5000)
        }
    }
    if ([System.IO.Directory]::Exists($testRoot)) {
        $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolvedTestRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not [System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('clashxy-tun-test-', [System.StringComparison]::Ordinal)) {
            throw 'Refusing to remove an unexpected TUN test directory.'
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
