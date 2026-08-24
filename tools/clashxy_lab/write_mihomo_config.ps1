[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [object]$ConfigDocument,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$astProperty = $ConfigDocument.PSObject.Properties['Ast']
if ($null -eq $astProperty -or $astProperty.Value -isnot [System.Collections.IDictionary]) {
    throw 'ConfigDocument must contain a dictionary Ast.'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    throw 'OutputPath must not be empty.'
}

$fullPath = [System.IO.Path]::GetFullPath($OutputPath)
$extension = [System.IO.Path]::GetExtension($fullPath)
if ($extension -notin @('.yaml', '.yml')) {
    throw 'Mihomo config OutputPath must use .yaml or .yml.'
}
$directory = [System.IO.Path]::GetDirectoryName($fullPath)
[void][System.IO.Directory]::CreateDirectory($directory)
$tempPath = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($fullPath) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
$yaml = $null

try {
    $yaml = & (Join-Path $PSScriptRoot 'convert_to_yaml.ps1') -Ast $astProperty.Value
    [System.IO.File]::WriteAllText($tempPath, $yaml, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($tempPath, $fullPath, $true)

    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    try {
        $sha256 = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        [pscustomobject][ordered]@{
            SchemaVersion = 1
            Written       = $true
            Path          = $fullPath
            ByteLength    = $bytes.Length
            Sha256        = $sha256
            ProxyCount    = [int]$ConfigDocument.ProxyCount
        }
    }
    finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
}
finally {
    $yaml = $null
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}
