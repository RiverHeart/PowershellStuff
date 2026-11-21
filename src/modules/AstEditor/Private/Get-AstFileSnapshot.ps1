using namespace System.IO
using namespace System.Text

<#
.SYNOPSIS
    Reads and decodes one byte snapshot without guessing legacy encodings.
#>
function Get-AstFileSnapshot {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    $Bytes = [File]::ReadAllBytes($Path)
    $PreambleLength = 0
    $Encoding = [UTF8Encoding]::new($false, $true)
    if ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE -and
        $Bytes[2] -eq 0 -and $Bytes[3] -eq 0
    ) {
        $Encoding = [UTF32Encoding]::new($false, $true, $true)
        $PreambleLength = 4
    } elseif ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0 -and $Bytes[1] -eq 0 -and
        $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF
    ) {
        $Encoding = [UTF32Encoding]::new($true, $true, $true)
        $PreambleLength = 4
    } elseif ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF
    ) {
        $Encoding = [UTF8Encoding]::new($true, $true)
        $PreambleLength = 3
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        $Encoding = [UnicodeEncoding]::new($false, $true, $true)
        $PreambleLength = 2
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        $Encoding = [UnicodeEncoding]::new($true, $true, $true)
        $PreambleLength = 2
    }

    try {
        $Text = $Encoding.GetString($Bytes, $PreambleLength, $Bytes.Length - $PreambleLength)
    } catch [DecoderFallbackException] {
        throw [InvalidDataException]::new(
            (Get-LocalizedString -Key 'CannotDecodeFile' -Args $Path),
            $_.Exception
        )
    }

    [pscustomobject]@{
        Text = $Text
        Encoding = $Encoding
        Fingerprint = Get-AstSourceFingerprint -Bytes $Bytes
    }
}
