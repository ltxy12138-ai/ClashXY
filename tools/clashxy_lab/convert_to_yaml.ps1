[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [object]$Ast
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lines = [System.Collections.Generic.List[string]]::new()

function Test-IsDictionary {
    param([AllowNull()][object]$Value)
    return $Value -is [System.Collections.IDictionary]
}

function Test-IsSequence {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value -or $Value -is [string] -or $Value -is [securestring]) {
        return $false
    }
    if ($Value -is [System.Collections.IDictionary]) {
        return $false
    }
    return $Value -is [System.Collections.IEnumerable]
}

function Format-YamlKey {
    param([Parameter(Mandatory)][string]$Value)

    if ($Value -match '^[A-Za-z_][A-Za-z0-9_-]*$' -and $Value -notmatch '^(?i:true|false|null|yes|no|on|off)$') {
        return $Value
    }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Format-YamlString {
    param([AllowEmptyString()][string]$Value)

    if ($Value -match "[\x00-\x08\x0B\x0C\x0E-\x1F\r\n]") {
        throw 'YAML string values must not contain control characters or line breaks.'
    }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Format-YamlScalar {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return 'null'
    }
    if ($Value -is [securestring]) {
        $plain = $null
        try {
            $plain = [System.Net.NetworkCredential]::new('', $Value).Password
            return Format-YamlString -Value $plain
        }
        finally {
            $plain = $null
        }
    }
    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }
    if ($Value -is [string] -or $Value -is [char]) {
        return Format-YamlString -Value ([string]$Value)
    }
    if (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64] -or
        $Value -is [single] -or $Value -is [double] -or
        $Value -is [decimal]
    ) {
        return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    }
    throw "Unsupported YAML scalar type '$($Value.GetType().FullName)'."
}

function Write-YamlNode {
    param(
        [AllowNull()]
        [object]$Node,

        [Parameter(Mandatory)]
        [int]$Indent
    )

    $padding = ' ' * $Indent

    if (Test-IsDictionary -Value $Node) {
        $dictionary = [System.Collections.IDictionary]$Node
        foreach ($keyObject in $dictionary.Keys) {
            $key = Format-YamlKey -Value ([string]$keyObject)
            $value = $dictionary[$keyObject]
            if (Test-IsDictionary -Value $value) {
                if ($value.Count -eq 0) {
                    [void]$lines.Add(('{0}{1}: {{}}' -f $padding, $key))
                }
                else {
                    [void]$lines.Add(('{0}{1}:' -f $padding, $key))
                    Write-YamlNode -Node $value -Indent ($Indent + 2)
                }
            }
            elseif (Test-IsSequence -Value $value) {
                $items = @($value)
                if ($items.Count -eq 0) {
                    [void]$lines.Add(('{0}{1}: []' -f $padding, $key))
                }
                else {
                    [void]$lines.Add(('{0}{1}:' -f $padding, $key))
                    Write-YamlNode -Node $items -Indent ($Indent + 2)
                }
            }
            else {
                $scalar = Format-YamlScalar -Value $value
                [void]$lines.Add(('{0}{1}: {2}' -f $padding, $key, $scalar))
            }
        }
        return
    }

    if (Test-IsSequence -Value $Node) {
        foreach ($item in @($Node)) {
            if (Test-IsDictionary -Value $item) {
                if ($item.Count -eq 0) {
                    [void]$lines.Add($padding + '- {}')
                }
                else {
                    [void]$lines.Add($padding + '-')
                    Write-YamlNode -Node $item -Indent ($Indent + 2)
                }
            }
            elseif (Test-IsSequence -Value $item) {
                $nested = @($item)
                if ($nested.Count -eq 0) {
                    [void]$lines.Add($padding + '- []')
                }
                else {
                    [void]$lines.Add($padding + '-')
                    Write-YamlNode -Node $nested -Indent ($Indent + 2)
                }
            }
            else {
                $scalar = Format-YamlScalar -Value $item
                [void]$lines.Add(('{0}- {1}' -f $padding, $scalar))
            }
        }
        return
    }

    [void]$lines.Add($padding + (Format-YamlScalar -Value $Node))
}

if (-not (Test-IsDictionary -Value $Ast)) {
    throw 'YAML document root must be a dictionary.'
}

Write-YamlNode -Node $Ast -Indent 0
return (($lines -join [char]10) + [char]10)
