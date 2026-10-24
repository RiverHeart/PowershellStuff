<#
.SYNOPSIS
    Removes one or more Nitpick rules.

.DESCRIPTION
    Removes registered rules from the module-level Nitpick registry by their
    exact, case-insensitive qualified ID (Namespace/Name).

.EXAMPLE
    Unregister-Nitpick -Id Local/Test-Formatting -Category Style

.EXAMPLE
    Unregister-Nitpick -Id 'Local/Test*'

.EXAMPLE
    Unregister-Nitpick -All
#>
function Unregister-Nitpick {
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Id,

        [Parameter(ParameterSetName = 'ById')]
        [ValidateSet('Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other')]
        [string] $Category,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch] $All
    )

    $Registry = Get-NitpickRegistry

    if ($All) {
        $Registry.Nitpicks.Clear()
        return
    }

    foreach ($RequestedId in $Id) {
        foreach ($Key in @($Registry.Nitpicks.Keys)) {
            $Nitpick = $Registry.Nitpicks[$Key]
            if ([string] $Key -like $RequestedId -and
                ([string]::IsNullOrEmpty($Category) -or $Nitpick.Category -eq $Category)
            ) {
                $null = $Registry.Nitpicks.Remove($Key)
            }
        }
    }
}
