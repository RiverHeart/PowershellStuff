<#
.SYNOPSIS
    Computes a SHA-256 fingerprint of source bytes.

.DESCRIPTION
    Computes a SHA-256 fingerprint of the provided source bytes or
    the contents of a file specified by the Path parameter.

.EXAMPLE
    Compute the fingerprint of a byte array.

    $Fingerprint = Get-AstSourceFingerprint -Bytes ([System.Text.Encoding]::UTF8.GetBytes('example'))

.EXAMPLE
    Compute the fingerprint of a file.

    $Fingerprint = Get-AstSourceFingerprint -Path 'C:\path\to\file.ps1'
#>
function Get-AstSourceFingerprint {
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory,ParameterSetName='Default')]
        [AllowEmptyCollection()]
        [byte[]] $Bytes,

        [Parameter(Mandatory,ParameterSetName='ByPath')]
        [string] $Path
    )

    $Hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            if (-not (Test-Path -Path $Path -PathType Leaf)) {
                Write-Error -Exception ([FileNotFoundException]::new("File '$Path' not found.", $Path))
                return
            }
            $Bytes = [System.IO.File]::ReadAllBytes($Path)
        }

        return [BitConverter]::ToString($Hasher.ComputeHash($Bytes)).Replace('-', '')
    } finally {
        if ($Hasher) {
            $Hasher.Dispose()
        }
    }
}
