<#
.SYNOPSIS
    Returns the module-level registry.

.DESCRIPTION
    Returns the module-level registry.
#>
function Get-NitpickRegistry {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param ()

    if (-not $script:Registry) {
        $script:Registry = [ordered] @{
            Nitpicks = @{}
        }
    }

    if (-not $script:Registry.Contains('Nitpicks')) {
        $script:Registry.Nitpicks = @{}
    }

    return $script:Registry
}
