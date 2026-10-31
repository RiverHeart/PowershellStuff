<#
.SYNOPSIS
    Resolves a version string to a [version] object, ensuring it has at least a major and minor component.

.DESCRIPTION
    This function takes a version string and converts it to a [version] object.
    If the version string only contains a major component, a minor component of 0 is appended.

.EXAMPLE
    Resolve a version string with only a major component.

    Resolve-Version -Version "1"

.EXAMPLE
    Resolve a version string with major and minor components.

    Resolve-Version -Version "1.2"

.EXAMPLE
    Resolve a version string with major, minor, and build components.

    Resolve-Version -Version "1.2.3"
#>
function Resolve-Version {
    [CmdletBinding()]
    [OutputType([version])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )
    process {
        if ($Version -notmatch '^\d+(\.\d+){0,3}$') {
            Write-Error "Invalid input '$Version'. Expected format: major[.minor[.build[.revision]]] (e.g., 1, 1.2, 1.2.3, 1.2.3.4)"
            return
        }
        if ($Version.IndexOf('.') -eq -1) {
            $ResolvedVersion = [Version]::new($Version, 0)
        } else {
            $ResolvedVersion = [version]::new($Version)
        }
        Write-Output $ResolvedVersion
    }
}
