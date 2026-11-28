<#
.SYNOPSIS
    Creates a new directory.

.DESCRIPTION
    Creates a new directory at the specified path. If the directory already exists,
    no action is taken.

.PARAMETER Path
    The path of the directory to create.

.PARAMETER PassThru
    If specified, returns a new or existing directory object.

.EXAMPLE
    Create a new directory at the specified path.

    New-Directory -Path 'C:\Example\Path'
#>
function New-Directory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [switch] $PassThru
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Write-Error "The path '$Path' is a file, not a directory."
        return
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($Path, "Create directory")) {
            $NewDir = New-Item -Type Directory -Path $Path -Force
            if ($PassThru) {
                return $NewDir
            }
        }
    } elseif ($PassThru) {
        return Get-Item -LiteralPath $Path -ErrorAction Stop
    }
}
