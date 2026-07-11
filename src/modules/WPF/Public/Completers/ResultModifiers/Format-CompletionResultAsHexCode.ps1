using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

<# WARNING: Non-functional. Keeping for reference #>

<#
.SYNOPSIS
    Formats completion results as hex codes.

.DESCRIPTION
    This function takes a CommandCompletion object and normalizes any six-digit hex
    completion text values to a standard format (for example, "#FFFFFF").

    Because CompletionMatches is enumerated during formatting, the function rebuilds the
    collection and assigns it back to the CommandCompletion object instead of mutating the
    collection while iterating.

.NOTES
    There is probably a better place to log this information but for now this is it

    This is just conjecture but I think the reason why it's so difficult to include the
    hexcode with the rest of the Colors is because PSReadLine filters results based on
    the CompletionText. If we type `ff` and attempt to replace with `#ff` PSReadLine
    will filter it out because the ReplacementIndex and Length on the CommandCompletion
    object don't reflect the new value but if we type 'Al' and attempt to replace with
    'AliceBlue' PSReadLine will handle it correctly.

    [Console] to [System.Console] is triggered in a different way via TabCompleteNext
    and, I suspect, has to be tab completed because the CommandCompletion object for
    each completion can only have a single replacement index/length set for it
    and different prefixes will produce different offsets.

.EXAMPLE
    Format completion result as hex code

    [CompletionResult] $CompletionResult = [CompletionResult]::new(
        'FFFFFF',
        'FFFFFF',
        [CompletionResultType]::ParameterValue,
        'Color'
    )

    $commandCompletion = [CommandCompletion]::new(
        [Collection[CompletionResult]]::new(),
        0,
        0,
        0
    )

    $commandCompletion.CompletionMatches.Add($CompletionResult)
    Format-CompletionResultAsHexCode -CommandCompletion $commandCompletion
    # Returns: [CommandCompletion] with CompletionMatches[0].CompletionText = "#FFFFFF"
#>
function Format-CompletionResultAsHexCode {
    [CmdletBinding()]
    [OutputType([CommandCompletion])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Alias('Completions')]
        [CommandCompletion] $CommandCompletion
    )

    process {
        $formattedCompletionMatches = [Collection[CompletionResult]]::new()

        foreach ($completion in $CommandCompletion.CompletionMatches) {
            $completionText = $completion.CompletionText

            try {
                if ($completionText -match '^[0-9A-Fa-f]{6}$') {
                    $ListItemText = if ([string]::IsNullOrEmpty($completion.ListItemText)) {
                        $completionText
                    } else {
                        $completion.ListItemText
                    }

                    $formattedCompletionMatches.Add([CompletionResult]::new(
                        <# Text to insert #> "#$completionText",
                        <# Text displayed in the list #> $ListItemText,
                        <# Icon Type #> $completion.ResultType,
                        <# Tooltip #> $completion.ToolTip
                    ))
                } else {
                    $formattedCompletionMatches.Add($completion)
                }
            } catch {
                Write-Error "Failed to format completion text '$completionText' as hex code. Error: $_"
                return $CommandCompletion
            }
        }

        $CommandCompletion.CompletionMatches = $formattedCompletionMatches
        return $CommandCompletion
    }
}
