<#
.SYNOPSIS
    Returns registered completion type mappings.

.DESCRIPTION
    Returns entries from the completion type registry used by `$this` completers.

.EXAMPLE
    Get-WPFCompletionType

.EXAMPLE
    Get-WPFCompletionType -Name FancyControl
#>
function Get-WPFCompletionType {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $Registry = Get-WPFCompletionTypeRegistry

    if (-not $PSBoundParameters.ContainsKey('Name')) {
        return @($Registry.Values)
    }

    foreach ($Entry in $Registry.GetEnumerator()) {
        if ([string] $Entry.Key -ieq $Name) {
            return $Entry.Value
        }
    }

    return $null
}
