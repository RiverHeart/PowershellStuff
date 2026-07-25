<#
.SYNOPSIS
    Enables TabCentral hook processing for tab completion.

.DESCRIPTION
    Sets the global TabCentral preference flag to true so TabCentral's
    TabExpansion2 wrapper evaluates registered hooks.
#>
function Enable-TabCentral {
    [CmdletBinding()]
    [OutputType([void])]
    param ()

    Write-Verbose "Enabling TabCentral hook processing."
    $global:TabCentralEnabled = $true
}
