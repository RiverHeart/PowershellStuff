<#
.SYNOPSIS
    Returns registered Nitpick hooks.

.DESCRIPTION
    Lists custom Nitpick hooks in the
    Nitpick registry.

.EXAMPLE
    Get-Nitpick

.EXAMPLE
    Get-Nitpick -Category Quality -Name Complete-Example
#>
function Get-Nitpick {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
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

    $Nitpicks = if ($Name) {
        $Registry.Nitpicks[$Name]
    } else {
        $Registry.Nitpicks.Values
    }

    $Nitpicks |
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
            -PropertyPath Name `
            -Include $IncludeRule `
            -Exclude $ExcludeRule `
            -Wildcard
}
