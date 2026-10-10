using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Provides tab completion for the Nitpick category parameter.

.DESCRIPTION
    Returns a list of possible Nitpick categories that match the user's input.

.EXAMPLE
    Complete-NitpickCategory -WordToComplete "S"
    # Returns "Style", "Security"
#>
function Complete-NitpickCategory {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    $Categories = 'Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other'

    $Completions = $Categories |
        Where-Object { $_ -ilike "*$WordToComplete*" } |
        Sort-Object -Property @(
            {
                # Tie results when no search term is provided to maintain alphabetical order.
                if ([string]::IsNullOrWhiteSpace($WordToComplete)) { 0 }
                # Otherwise, prioritize results that start with the search term.
                else { [int]($_ -inotlike "$WordToComplete*") }
            },
            { $_  <# Always keep deterministic alphabetical ordering. #> }
        ) |
        ForEach-Object {
            $CompletionText = if ($Quote) { $Quote + $_ + $Quote  } else { $_ }
            [CompletionResult]::new(
                <# Text to insert #> $CompletionText,
                <# Text displayed in the list #> $_,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> "Nitpick Category"
            )
        }

    if ($Completions.Count -gt 0) { return $Completions }
    return $null  # Prevent fallback autocomplete
}
