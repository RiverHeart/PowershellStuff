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
            $Nitpick = $_

            if ($Name -and $_.Name -ne $Name) {
                return $false
            }

            if ($Category -and $_.Category -ne $Category) {
                return $false
            }

            [bool] $IsIncluded = -not $IncludeRule -or ($IncludeRule | Where-Object { $Nitpick.Name -like $_ })
            [bool] $IsExcluded = $ExcludeRule -and ($ExcludeRule | Where-Object { $Nitpick.Name -like $_ })

            return $IsIncluded -and -not $IsExcluded
        }
}
