using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Provides auto-complete for colors.

.DESCRIPTION
    Provides auto-complete for colors defined in System.Windows.Media.Colors.

.EXAMPLE
    Complete a color

    Complete-WPFColor -WordToComplete 'Ali'
    # Returns: AliceBlue
#>
function Complete-WPFColor {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CompletionResult], [System.Management.Automation.CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    $ColorNames = @(
        [System.Windows.Media.Colors].GetProperties().Name
    )
    $HexCompletions = @()

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) { $WordToComplete = $WordToComplete.Trim($Quote) }

    $HexMatch = [Regex]::Match($WordToComplete, '^#?(?<Hex>[0-9A-Fa-f]{1,8})$')
    $SupportsHexCompletion = $false

    if ($HexMatch.Success) {
        $hexDigits = $HexMatch.Groups['Hex'].Value
        $SupportsHexCompletion = $true
        $hexValue = "#$hexDigits"
        $HexQuote = if ($Quote) { $Quote } else { "'" }
        $completionText = $HexQuote + $hexValue + $HexQuote

        $HexCompletions = @(
            [CompletionResult]::new(
                <# Text to insert #> $completionText,
                <# Text displayed in the list #> $wordToComplete,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> 'Hex color'
            )
        )
    }

    # The results are already alphabetical so no need to sort these.
    $Completions = $ColorNames |
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
                <# Tooltip #> "Color"
            )
        }

    if ($SupportsHexCompletion) {
        $Completions = @($HexCompletions) + @($Completions)
    }

    if ($Completions.Count -gt 0) { return $Completions }
    return $null  # Prevent fallback autocomplete
}
