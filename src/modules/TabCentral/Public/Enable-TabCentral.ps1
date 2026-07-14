<#
.SYNOPSIS
    Enables TabCentral hook processing for tab completion.

.DESCRIPTION
    Sets the global TabCentral preference flag to true so TabCentral's
    TabExpansion2 wrapper evaluates registered hooks.
#>
function Enable-TabCentral {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $global:TabCentralEnabled = $true
    return $global:TabCentralEnabled
}
