[CmdletBinding()]
param(
    [string]$OldPortableZip = (Join-Path $PSScriptRoot '..\dist\ClashXY-Windows-x64-1.9.0-build14.zip'),
    [string]$NewInstaller,
    [string]$Iscc,
    [switch]$InstallOnly,
    [switch]$RequireValidSignature,
    [string]$ExpectedPublisherPattern
)

$ErrorActionPreference = 'Stop'
$repository = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pubspec = Join-Path $repository 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspec -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$' | Select-Object -First 1
if ($null -eq $versionLine) {
    throw 'pubspec.yaml must contain a semantic version and numeric build.'
}
$newVersion = $versionLine.Matches[0].Groups[1].Value
$newBuild = $versionLine.Matches[0].Groups[2].Value

$oldArchive = $null
$oldVersion = $null
$oldBuild = $null
if (-not $InstallOnly) {
    $oldArchive = [System.IO.Path]::GetFullPath($OldPortableZip)
    if (-not (Test-Path -LiteralPath $oldArchive)) {
        throw "Old portable archive was not found: $oldArchive"
    }
    $oldName = [System.IO.Path]::GetFileName($oldArchive)
    $oldMatch = [regex]::Match($oldName, '^ClashXY-Windows-x64-(\d+\.\d+\.\d+)-build(\d+)\.zip$')
    if (-not $oldMatch.Success) {
        throw 'Old portable archive name must be ClashXY-Windows-x64-<version>-build<build>.zip.'
    }
    $oldVersion = $oldMatch.Groups[1].Value
    $oldBuild = $oldMatch.Groups[2].Value
}

if ([string]::IsNullOrWhiteSpace($NewInstaller)) {
    $NewInstaller = Join-Path $repository "dist\ClashXY-Setup-x64-$newVersion-build$newBuild.exe"
}
$newInstallerPath = [System.IO.Path]::GetFullPath($NewInstaller)
if (-not (Test-Path -LiteralPath $newInstallerPath)) {
    throw "New installer was not found: $newInstallerPath"
}

if ($RequireValidSignature -and [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
    throw '-ExpectedPublisherPattern is required with -RequireValidSignature.'
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern) -and -not $RequireValidSignature) {
    throw '-ExpectedPublisherPattern requires -RequireValidSignature.'
}
$signatureVerifier = Join-Path $PSScriptRoot 'verify_windows_signatures.ps1'
$installerPublisher = $null
if ($RequireValidSignature) {
    $verifyArguments = @{ Path = @($newInstallerPath) }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
        $verifyArguments.ExpectedPublisherPattern = $ExpectedPublisherPattern
    }
    $installerSignature = @(& $signatureVerifier @verifyArguments)
    $installerSignature | Out-Host
    $installerPublisher = $installerSignature[0].Publisher
}

if (-not $InstallOnly -and [string]::IsNullOrWhiteSpace($Iscc)) {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $Iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $InstallOnly -and ([string]::IsNullOrWhiteSpace($Iscc) -or -not (Test-Path -LiteralPath $Iscc))) {
    throw 'Inno Setup 6 compiler was not found.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Installer upgrade verification requires an elevated PowerShell session.'
}

$uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{B653B669-E2AB-4D8C-9F65-E642A15D3B45}_is1'
if (Test-Path -LiteralPath $uninstallKey) {
    throw 'A ClashXY installation already owns the release AppId. Uninstall it before running this isolated test.'
}
if (Get-Process -Name ClashXY -ErrorAction SilentlyContinue) {
    throw 'Close ClashXY before running the installer upgrade verification.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$testRoot = [System.IO.Path]::GetFullPath((Join-Path $repository "build\installer-e2e\$stamp"))
$oldPackage = Join-Path $testRoot 'old-package'
$oldOutput = Join-Path $testRoot 'old-installer'
$installDirectory = Join-Path $testRoot 'installed'
[System.IO.Directory]::CreateDirectory($oldPackage) | Out-Null
[System.IO.Directory]::CreateDirectory($oldOutput) | Out-Null

function Get-AppDataFingerprint {
    param([string]$Root)
    $result = @{}
    if (-not (Test-Path -LiteralPath $Root)) {
        return $result
    }
    Get-ChildItem -LiteralPath $Root -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $relative = $_.FullName.Substring($Root.Length)
            $result[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        } catch {
            throw "Unable to fingerprint an existing ClashXY data file: $($_.Exception.Message)"
        }
    }
    return $result
}

function Test-FingerprintEqual {
    param([hashtable]$Before, [hashtable]$After)
    if ($Before.Count -ne $After.Count) {
        return $false
    }
    foreach ($key in $Before.Keys) {
        if (-not $After.ContainsKey($key) -or $After[$key] -ne $Before[$key]) {
            return $false
        }
    }
    return $true
}

function Invoke-HiddenProcess {
    param([string]$FilePath, [string[]]$ArgumentList)
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$([System.IO.Path]::GetFileName($FilePath)) failed with exit code $($process.ExitCode)."
    }
}

$appDataRoot = Join-Path $env:APPDATA 'app.mymihomo\mymihomo'
$before = Get-AppDataFingerprint -Root $appDataRoot
$uninstaller = Join-Path $installDirectory 'unins000.exe'
$uninstalled = $false

try {
    $installedExecutable = Join-Path $installDirectory 'ClashXY.exe'
    $installedOldVersion = $null
    if (-not $InstallOnly) {
        Expand-Archive -LiteralPath $oldArchive -DestinationPath $oldPackage
        $oldSource = Join-Path $oldPackage 'ClashXY'
        if (-not (Test-Path -LiteralPath (Join-Path $oldSource 'ClashXY.exe'))) {
            throw 'Old portable archive does not contain ClashXY/ClashXY.exe.'
        }

        & ([System.IO.Path]::GetFullPath($Iscc)) @(
            '/Qp',
            "/DAppVersion=$oldVersion",
            "/DAppBuild=$oldBuild",
            "/DSourceDir=$oldSource",
            "/DOutputDir=$oldOutput",
            (Join-Path $repository 'installer\ClashXY.iss')
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Old installer compilation failed with exit code $LASTEXITCODE."
        }

        $oldInstaller = Join-Path $oldOutput "ClashXY-Setup-x64-$oldVersion-build$oldBuild.exe"
        Invoke-HiddenProcess -FilePath $oldInstaller -ArgumentList @(
            '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
            ('/DIR="{0}"' -f $installDirectory),
            ('/LOG="{0}"' -f (Join-Path $testRoot 'install-old.log'))
        )

        $installedOldVersion = (Get-Item -LiteralPath $installedExecutable).VersionInfo.ProductVersion.Trim()
        if ($installedOldVersion -ne "$oldVersion+$oldBuild") {
            throw "Old install version mismatch: $installedOldVersion"
        }
    }

    Invoke-HiddenProcess -FilePath $newInstallerPath -ArgumentList @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
        ('/DIR="{0}"' -f $installDirectory),
        ('/LOG="{0}"' -f (Join-Path $testRoot 'upgrade-new.log'))
    )
    $installedNewVersion = (Get-Item -LiteralPath $installedExecutable).VersionInfo.ProductVersion.Trim()
    if ($installedNewVersion -ne "$newVersion+$newBuild") {
        throw "Upgraded install version mismatch: $installedNewVersion"
    }

    if ($RequireValidSignature) {
        $verifyArguments = @{ Path = @($installedExecutable, $uninstaller) }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
            $verifyArguments.ExpectedPublisherPattern = $ExpectedPublisherPattern
        }
        $installedSignatures = @(& $signatureVerifier @verifyArguments)
        $installedSignatures | Out-Host
        if (@($installedSignatures | Where-Object { $_.Publisher -ne $installerPublisher }).Count -gt 0) {
            throw 'Installed ClashXY.exe and uninstaller must use the installer Authenticode publisher.'
        }
    }

    $after = Get-AppDataFingerprint -Root $appDataRoot
    if (-not (Test-FingerprintEqual -Before $before -After $after)) {
        throw 'Installer upgrade changed existing ClashXY application data.'
    }

    Invoke-HiddenProcess -FilePath $uninstaller -ArgumentList @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART',
        ('/LOG="{0}"' -f (Join-Path $testRoot 'uninstall.log'))
    )
    $uninstalled = $true
    Start-Sleep -Seconds 1
    if (Test-Path -LiteralPath $installDirectory) {
        throw 'Install directory remained after uninstall.'
    }
    if (Test-Path -LiteralPath $uninstallKey) {
        throw 'Uninstall registry key remained after uninstall.'
    }

    [pscustomobject]@{
        TestRoot              = $testRoot
        Mode                  = $(if ($InstallOnly) { 'install' } else { 'upgrade' })
        OldProductVersion     = $installedOldVersion
        NewProductVersion     = $installedNewVersion
        AppDataFilesPreserved = $before.Count
        Uninstalled           = $true
    }
} finally {
    if (-not $uninstalled -and (Test-Path -LiteralPath $uninstaller)) {
        try {
            Invoke-HiddenProcess -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
        } catch {
            Write-Warning "Automatic test cleanup failed: $($_.Exception.Message)"
        }
    }
}
