<#
.SYNOPSIS
    Returns the module-level tab central hook registry.

.DESCRIPTION
    Returns the registry containing tab completers and result modifiers
    registered with TabCentral.
#>
function Get-TabCentralRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param ()

    if (-not $script:TabExpansionRegistry) {
        $script:TabExpansionRegistry = [ordered] @{
            TabCompleters = @{}
            ResultModifiers = @{}
        }
    }

    if (-not $script:TabExpansionRegistry.Contains('TabCompleters')) {
        $script:TabExpansionRegistry.TabCompleters = @{}
    }

    if (-not $script:TabExpansionRegistry.Contains('ResultModifiers')) {
        $script:TabExpansionRegistry.ResultModifiers = @{}
    }

    return $script:TabExpansionRegistry
}
