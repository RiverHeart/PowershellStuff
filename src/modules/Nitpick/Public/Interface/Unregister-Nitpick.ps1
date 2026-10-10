<#
.SYNOPSIS
    Removes one or more Nitpick rules.

.DESCRIPTION
    Removes registered rules from the module-level Nitpick registry.

.EXAMPLE
    Unregister-Nitpick -Name Test-Formatting -Category Style

.EXAMPLE
    Unregister-Nitpick -Name Test*

.EXAMPLE
    Unregister-Nitpick -All
#>
function Unregister-Nitpick {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [Parameter(ParameterSetName = 'ByName')]
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

    foreach ($RequestedName in $Name) {
        foreach ($Key in @($Registry.Nitpicks.Keys)) {
            $Nitpick = $Registry.Nitpicks[$Key]
            if ([string] $Key -like $RequestedName -and
                ([string]::IsNullOrEmpty($Category) -or $Nitpick.Category -eq $Category)
            ) {
                $null = $Registry.Nitpicks.Remove($Key)
            }
        }
    }
}
