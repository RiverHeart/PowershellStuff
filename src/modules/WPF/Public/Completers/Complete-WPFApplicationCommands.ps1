using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Provides auto-complete for the Name parameter of the New-WPFRoutedUICommand cmdlet.
#>
function Complete-WPFApplicationCommand {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) {
        $WordToComplete = $WordToComplete.Trim($Quote)
    }

    $Completions = [System.Windows.Input.ApplicationCommands].GetProperties().name |
        Where-Object {
            $_.StartsWith($WordToComplete, [StringComparison]::InvariantCultureIgnoreCase)
        } |
        Sort-Object |
        ForEach-Object {
            $CompletionText = if ($Quote) { $Quote + $_ + $Quote  } else { $_ }
            [CompletionResult]::new(
                <# Text to insert #> $CompletionText,
                <# Text displayed in the list #> $_,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> 'Registered WPF Objects'
            )
        }

    if ($Completions.Count -gt 0) {
        return $Completions
    }
    return $null  # Prevent fallback autocomplete
}

