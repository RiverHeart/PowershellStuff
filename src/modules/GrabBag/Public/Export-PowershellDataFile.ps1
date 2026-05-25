function Export-PowershellDataFile {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [AllowNull()]
        [Object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Path,

        [uint32] $IndentSize = 4,
        [string] $Key,
        [System.CodeDom.Compiler.IndentedTextWriter] $IndentedTextWriter
    )

    $IsRoot = $false
    $FileStream = $null
    $StreamWriter = $null

    try {
        if (-not $IndentedTextWriter) {
            $IsRoot = $true
            $FileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $StreamWriter = [System.IO.StreamWriter]::new($FileStream, [System.Text.Encoding]::UTF8)
            $IndentedTextWriter = [System.CodeDom.Compiler.IndentedTextWriter]::new($StreamWriter, " " * $IndentSize)
        }

        $SharedParams = @{
            Path = $Path
            IndentSize = $IndentSize
            IndentedTextWriter = $IndentedTextWriter
        }

        function Format-HashtableKey {
            [OutputType([string])]
            param (
                [string] $RawKey
            )

            if ([string]::IsNullOrEmpty($RawKey)) {
                return $null
            }

            if ($RawKey -match '^[A-Za-z_][A-Za-z0-9_]*$') {
                return $RawKey
            }

            $EscapedKey = $RawKey -replace "'", "''"
            return "'$EscapedKey'"
        }

        function Format-Scalar {
            [OutputType([string])]
            param (
                [AllowNull()]
                [Object] $Value
            )

            if ($null -eq $Value) { return '$null' }

            if ($Value -is [string] -or $Value -is [char]) {
                $EscapedValue = $Value.ToString() -replace "'", "''"
                return "'$EscapedValue'"
            }

            if ($Value -is [bool]) {
                if ($Value) { return '$true' } else { return '$false' }
            }

            return [string] $Value
        }

        $FormattedKey = Format-HashtableKey $Key

        if ($InputObject -is [Hashtable]) {
            if ($FormattedKey) {
                $IndentedTextWriter.WriteLine("$FormattedKey = @{")
            } else {
                $IndentedTextWriter.WriteLine('@{')
            }

            $IndentedTextWriter.Indent++
            foreach ($EntryKey in $InputObject.Keys) {
                Export-PowershellDataFile -InputObject $InputObject[$EntryKey] -Key $EntryKey @SharedParams
            }
            $IndentedTextWriter.Indent--
            $IndentedTextWriter.WriteLine('}')
        }
        elseif ($InputObject -is [PSCustomObject]) {
            if ($FormattedKey) {
                $IndentedTextWriter.WriteLine("$FormattedKey = @{")
            } else {
                $IndentedTextWriter.WriteLine('@{')
            }

            $IndentedTextWriter.Indent++
            $CustomProperties = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
            foreach ($Property in $CustomProperties) {
                Export-PowershellDataFile -InputObject $Property.Value -Key $Property.Name @SharedParams
            }
            $IndentedTextWriter.Indent--
            $IndentedTextWriter.WriteLine('}')
        }
        elseif ($InputObject -is [array]) {
            if ($FormattedKey) {
                $IndentedTextWriter.WriteLine("$FormattedKey = @(")
            } else {
                $IndentedTextWriter.WriteLine('@(')
            }

            $IndentedTextWriter.Indent++
            foreach ($Item in $InputObject) {
                Export-PowershellDataFile -InputObject $Item @SharedParams
            }
            $IndentedTextWriter.Indent--
            $IndentedTextWriter.WriteLine(')')
        }
        else {
            $FormattedValue = Format-Scalar $InputObject
            if ($FormattedKey) {
                $IndentedTextWriter.WriteLine("$FormattedKey = $FormattedValue")
            } else {
                $IndentedTextWriter.WriteLine($FormattedValue)
            }
        }
    }
    finally {
        if ($IsRoot) {
            if ($IndentedTextWriter) {
                $IndentedTextWriter.Flush()
                $IndentedTextWriter.Dispose()
            }

            if ($StreamWriter) { $StreamWriter.Dispose() }

            if ($FileStream) { $FileStream.Dispose() }
        }
    }
}
