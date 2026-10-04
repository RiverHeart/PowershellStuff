<#
.SYNOPSIS
    Computes a SHA-256 fingerprint of source bytes.
#>
function Get-AstSourceFingerprint {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]] $Bytes
    )

    $Hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($Hasher.ComputeHash($Bytes)).Replace('-', '')
    } finally {
        $Hasher.Dispose()
    }
}
