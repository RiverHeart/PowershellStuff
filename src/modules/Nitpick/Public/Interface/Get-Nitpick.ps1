<#
.SYNOPSIS
    Returns registered Nitpick hooks.

.DESCRIPTION
    Lists custom Nitpick hooks in the
    Nitpick registry.

.EXAMPLE
    Get-Nitpick

.EXAMPLE
    Get-Nitpick -Type Quality -Name Complete-Example
#>
function Get-Nitpick {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]] $Name,

        [ValidateSet('Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other')]
        [string] $Type
    )

    $Registry = Get-NitpickRegistry
    $Registry.Nitpicks.Values |
        Where-Object {
            $NitpickName = $_.Name
            ([string]::IsNullOrEmpty($Type) -or $_.Type -eq $Type) -and
            ([string]::IsNullOrEmpty($Name) -or [bool] ($Name | Where-Object { $NitpickName -like $_ }))
        }
}
