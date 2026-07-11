<#
.SYNOPSIS
    Returns the module-level tab expansion hook registry.

.DESCRIPTION
    Provides access to tab completer and result modifier hooks used by the
    WPF TabExpansion2 wrapper.
#>
function Get-WPFTabExpansionRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $script:TabExpansionRegistry) {
        if ($global:TabExpansionRegistry -is [hashtable]) {
            $script:TabExpansionRegistry = $global:TabExpansionRegistry
            Remove-Variable -Name TabExpansionRegistry -Scope Global -ErrorAction SilentlyContinue
        } else {
            $script:TabExpansionRegistry = [ordered] @{
                TabCompleters = @{}
                ResultModifiers = @{}
            }
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
