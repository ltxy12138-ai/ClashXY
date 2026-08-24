[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string[]]$Path,
    [string]$ExpectedPublisherPattern,
    [switch]$AllowMissingTimestamp,
    [switch]$SkipSignTool
)

begin {
    $ErrorActionPreference = 'Stop'
    $requestedPaths = [System.Collections.Generic.List[string]]::new()
}

process {
    foreach ($item in $Path) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $requestedPaths.Add($item)
        }
    }
}

end {
    if ($requestedPaths.Count -eq 0) {
        throw 'At least one signed file path is required.'
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern)) {
        try {
            [void][regex]::new($ExpectedPublisherPattern)
        } catch {
            throw "Expected publisher pattern is not a valid regular expression: $ExpectedPublisherPattern"
        }
    }

    $signTool = $null
    if (-not $SkipSignTool) {
        $command = Get-Command 'signtool.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            $signTool = $command.Source
        } else {
            $kitRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
            if (Test-Path -LiteralPath $kitRoot) {
                $signTool = Get-ChildItem -LiteralPath $kitRoot -Directory -ErrorAction SilentlyContinue |
                    ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
                    Where-Object { Test-Path -LiteralPath $_ } |
                    Sort-Object { [version]([System.IO.DirectoryInfo]::new((Split-Path (Split-Path $_ -Parent) -Parent))).Name } -Descending |
                    Select-Object -First 1
            }
        }
        if ([string]::IsNullOrWhiteSpace($signTool)) {
            throw 'signtool.exe was not found. Install the Windows SDK or pass -SkipSignTool for PowerShell-only diagnostics.'
        }
    }

    $results = foreach ($item in $requestedPaths) {
        $fullPath = [System.IO.Path]::GetFullPath($item)
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Signed file was not found: $fullPath"
        }

        $signature = Get-AuthenticodeSignature -LiteralPath $fullPath
        if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
            throw "Authenticode signature is not valid for $fullPath. Status: $($signature.Status). $($signature.StatusMessage)"
        }
        $signer = $signature.SignerCertificate
        if ($null -eq $signer) {
            throw "Authenticode signer certificate is missing for $fullPath."
        }
        $ekuOids = @($signer.EnhancedKeyUsageList | ForEach-Object {
            if ($_.ObjectId -is [string]) { $_.ObjectId } else { $_.ObjectId.Value }
        })
        if ($ekuOids -notcontains '1.3.6.1.5.5.7.3.3') {
            throw "Signer certificate for $fullPath does not contain the Code Signing EKU."
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisherPattern) -and
            $signer.Subject -notmatch $ExpectedPublisherPattern) {
            throw "Signer subject for $fullPath does not match the expected publisher pattern. Subject: $($signer.Subject)"
        }
        $timestamp = $signature.TimeStamperCertificate
        if (-not $AllowMissingTimestamp -and $null -eq $timestamp) {
            throw "A trusted timestamp is required for $fullPath."
        }

        if (-not $SkipSignTool) {
            $verificationOutput = @(& $signTool verify /pa /all /v $fullPath 2>&1)
            if ($LASTEXITCODE -ne 0) {
                $tail = ($verificationOutput | Select-Object -Last 30) -join [Environment]::NewLine
                throw "signtool verification failed for $fullPath.`n$tail"
            }
        }

        [pscustomobject]@{
            Path             = $fullPath
            SHA256           = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
            Status           = $signature.Status.ToString()
            Publisher        = $signer.Subject
            Thumbprint       = $signer.Thumbprint
            Timestamped      = $null -ne $timestamp
            TimestampSubject = $(if ($null -ne $timestamp) { $timestamp.Subject } else { $null })
            SignToolVerified = -not $SkipSignTool
        }
    }

    $results
}
