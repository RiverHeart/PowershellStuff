<#
.SYNOPSIS
    Returns registered Nitpick hooks.

.DESCRIPTION
    Lists custom Nitpick hooks in the
    Nitpick registry.

.PARAMETER Id
    Exact or wildcard qualified rule ID (Namespace/Name), case-insensitive.

.EXAMPLE
    Get-Nitpick

.EXAMPLE
    Get-Nitpick -Category Quality -Name Complete-Example

.EXAMPLE
    Get-Nitpick -Id Local/AvoidFoo
#>
function Get-Nitpick {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]] $Id,

        [string] $Name,

        [ArgumentCompleter({ Complete-NitpickCategory })]
        [string] $Category,

        [ArgumentCompleter({ Complete-NitpickCategory })]
        [string[]] $IncludeCategory,

        [ArgumentCompleter({ Complete-NitpickCategory })]
        [string[]] $ExcludeCategory,

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule
    )

    $Registry = Get-NitpickRegistry

    $Registry.Nitpicks.Values |
        Where-Object {
            # Exact name match
            if ($Name -and $_.Name -ne $Name) {
                return $false
            }

            # Exact category match
            if ($Category -and $_.Category -ne $Category) {
                return $false
            }

            return $true
        } |
        Where-NitpickIncluded `
            -PropertyPath Category `
            -Include $IncludeCategory `
            -Exclude $ExcludeCategory `
            -Wildcard |
        Where-NitpickIncluded `
            -PropertyPath Id `
            -Include $Id `
            -Wildcard |
        Where-NitpickIncluded `
            -PropertyPath Id `
            -Include $IncludeRule `
            -Exclude $ExcludeRule `
            -Wildcard
}
