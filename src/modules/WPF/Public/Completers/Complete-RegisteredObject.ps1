<#
.SYNOPSIS
    Provides auto-complete for the Event parameter of the Add-WPFHandler cmdlet.

.DESCRIPTION
    Provides auto-complete for the Event parameter of the Add-WPFHandler cmdlet.

    Because `ArgumentCompleterAttribute` passes a scriptblock bound `CommandAST`
    to the completer function we cannot see the type of command the handler needs
    to provide completion for by traversing the `Parent` property of the AST node.

    To work around this, we use the callstack to get the invocation args passed to TabExpansion2.
    Among those arguments are the full AST and the cursor position. With those, we can
    search the AST to get the calling node and find the command value (e.g. `Button`)
    to determine what values should be returned.
#>
function Complete-RegisteredObject {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
    )

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) {
        $WordToComplete = $WordToComplete.Trim($Quote)
    }

    $Completions = $script:WPFControlTable.Keys |
        Where-Object {
            $_.StartsWith($WordToComplete, [System.StringComparison]::InvariantCultureIgnoreCase)
        } |
        Sort-Object |
        ForEach-Object {
            $CompletionText = if ($Quote) { $Quote + $_ + $Quote  } else { $_ }
            [System.Management.Automation.CompletionResult]::new(
                <# Text to insert #> $CompletionText,
                <# Text displayed in the list #> $_,
                <# Result type #> [System.Management.Automation.CompletionResultType]::ParameterValue,
                <# Tooltip #> 'Registered WPF Objects'
            )
        }

    if ($Completions.Count -gt 0) {
        return $Completions
    }
    return $null  # Prevent fallback autocomplete
}
