<#
.SYNOPSIS
    Returns the module-level completion type registry.

.DESCRIPTION
    Provides access to completion type mappings used by `$this` completers.
    This registry is keyed by keyword/control name and stores resolved .NET types.
#>
function Get-WPFCompletionTypeRegistry {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param()

    if (-not $script:WPFCompletionTypeRegistry) {
        $script:WPFCompletionTypeRegistry = [ordered] @{}
    }

    return $script:WPFCompletionTypeRegistry
}
