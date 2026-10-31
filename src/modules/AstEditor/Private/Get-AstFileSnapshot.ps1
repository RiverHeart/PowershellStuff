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

    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    $PreambleLength = 0
    $Encoding = [System.Text.UTF8Encoding]::new($false, $true)
    if ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE -and
        $Bytes[2] -eq 0 -and $Bytes[3] -eq 0
    ) {
        $Encoding = [System.Text.UTF32Encoding]::new($false, $true, $true)
        $PreambleLength = 4
    } elseif ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0 -and $Bytes[1] -eq 0 -and
        $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF
    ) {
        $Encoding = [System.Text.UTF32Encoding]::new($true, $true, $true)
        $PreambleLength = 4
    } elseif ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF
    ) {
        $Encoding = [System.Text.UTF8Encoding]::new($true, $true)
        $PreambleLength = 3
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        $Encoding = [System.Text.UnicodeEncoding]::new($false, $true, $true)
        $PreambleLength = 2
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        $Encoding = [System.Text.UnicodeEncoding]::new($true, $true, $true)
        $PreambleLength = 2
    }

    try {
        $Text = $Encoding.GetString($Bytes, $PreambleLength, $Bytes.Length - $PreambleLength)
    } catch [System.Text.DecoderFallbackException] {
        throw [System.IO.InvalidDataException]::new(
            "Cannot decode '$Path'. Use valid UTF-8 or BOM-marked UTF-8, UTF-16, or UTF-32; legacy encodings are not inferred.",
            $_.Exception
        )
    }

    [pscustomobject]@{
        Text = $Text
        Encoding = $Encoding
        Fingerprint = Get-AstSourceFingerprint -Bytes $Bytes
    }
}
