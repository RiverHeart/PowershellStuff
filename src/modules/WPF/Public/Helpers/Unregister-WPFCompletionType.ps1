<#
.SYNOPSIS
    Removes one or more completion type mappings.

.DESCRIPTION
    Removes entries from the completion type registry used by `$this` completers.

.EXAMPLE
    Unregister-WPFCompletionType -Name FancyControl

.EXAMPLE
    Unregister-WPFCompletionType -All
#>
function Unregister-WPFCompletionType {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch] $All
    )

    $Registry = Get-WPFCompletionTypeRegistry

    if ($PSCmdlet.ParameterSetName -eq 'All') {
        $Registry.Clear()
        if ($script:WPFThisCompletionCache -and $script:WPFThisCompletionCache.Completions) {
            $script:WPFThisCompletionCache.Completions.Clear()
        }

        return
    }

    foreach ($Item in $Name) {
        $MatchedKey = $null
        foreach ($Entry in $Registry.GetEnumerator()) {
            if ([string] $Entry.Key -ieq $Item) {
                $MatchedKey = $Entry.Key
                break
            }
        }

        if ($MatchedKey) {
            $null = $Registry.Remove($MatchedKey)
        }

        if ($script:WPFThisCompletionCache -and $script:WPFThisCompletionCache.Completions) {
            $null = $script:WPFThisCompletionCache.Completions.Remove($Item)
        }
    }
}
