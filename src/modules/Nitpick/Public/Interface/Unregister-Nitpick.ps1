<#
.SYNOPSIS
    Removes one or more TabCentral hooks.

.DESCRIPTION
    Removes registered tab completers and result modifiers from the module-level
    tab central registry.

.EXAMPLE
    Unregister-Nitpick -Name Complete-WPFThis -Type Completer

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
        [string] $Type,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch] $All
    )

    $Registry = Get-NitpickRegistry

    foreach ($RequestedName in $Name) {
        foreach ($Key in @($Registry.Nitpicks.Keys)) {
            if ([string] $Key -like $RequestedName) {
                $null = $Registry.Nitpicks.Remove($Key)
            }
        }
    }
}
