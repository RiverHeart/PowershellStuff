<#
.SYNOPSIS
    Disables TabCentral hook processing for tab completion.

.DESCRIPTION
    Sets the global TabCentral preference flag to false so TabCentral's
    TabExpansion2 wrapper immediately falls back to the original completion
    behavior.
#>
function Disable-TabCentral {
    [CmdletBinding()]
    [OutputType([void])]
    param ()

    Write-Verbose "Disabling TabCentral hook processing."
    $global:TabCentralEnabled = $false
}
