using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Provides tab completion for State keys within the current command scope.

.DESCRIPTION
    Provides tab completion for State keys within the current command scope.

    This completer searches the command AST path containing the cursor for any
    State commands, and returns the keys from hashtables passed to those commands.
    This allows discovery of available state keys within the current command context.

    Because `ArgumentCompleterAttribute` passes a scriptblock bound `CommandAST`
    to the completer function we cannot see the type of command the state belongs
    to by traversing the `Parent` property of the AST node. To work around this, we use
    the callstack to get the invocation args passed to TabExpansion2. Among those
    arguments are the full AST and the cursor position. With those, we can search the
    AST to get the calling node and find the command value (e.g. `Button`) to determine
    what values should be returned.

.NOTES
    * This implementation is potentially expensive for large ASTs. Powershell only
      calls the completers once then filters an in-memory copy of results as the user types.
      Only if the user presses backspace or re-triggers completion will the completer be
      called again. Therefore, it's unlikely to become an issue. If, somehow, it did
      become an issue we could cache the unfiltered property names for a short time.

    * Right now we're only returning properties within the AST path leading to the cursor
      but if we expect users to call state from across the entire application we should be
      including all State declarations.

.EXAMPLE
    Given the following command structure:

    Window {
        State @{
            Foo = 'Foo'
            Bar = 'Bar'
        }

        # Cursor is here -> ^
        When ^
    }

    When invoking tab completion for State properties within the Window block,
    the completer will return "Foo" and "Bar" as possible completions.
#>
function Complete-WPFState {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    try {
        # Find all commands that contain the cursor, then inspect each command scope
        # for top-level State declarations.
        $CursorPathCommandNodes = Find-AstNode -Type CommandAst -All -Recurse -ContainsCursor
    } catch {
        Write-Debug "Failed to resolve AST context for state completion: $($_.Exception.Message)"
        return
    }

    if (-not $CursorPathCommandNodes) {
        Write-Debug 'Failed to find command path for current cursor location'
        return
    }

    $AvailableStateMap = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($PathNode in @($CursorPathCommandNodes)) {
        $ScopeScriptBlockExpression = @($PathNode.CommandElements | Where-Object {
                $_ -is [ScriptBlockExpressionAst]
            }) | Select-Object -Last 1

        if (-not $ScopeScriptBlockExpression) {
            continue
        }

        $ScopeScriptBlock = $ScopeScriptBlockExpression.ScriptBlock
        if (-not $ScopeScriptBlock) {
            continue
        }

        $StateNodesInScope = Find-AstNode -Ast $ScopeScriptBlock -Type CommandAst -All -Query {
            $_.GetCommandName() -ieq 'State'
        }

        foreach ($StateNode in @($StateNodesInScope)) {
            $HashtableArgument = @($StateNode.CommandElements | Select-Object -Skip 1 -First 1)[0]
            if (-not ($HashtableArgument -is [HashtableAst])) {
                continue
            }

            foreach ($Entry in @($HashtableArgument.KeyValuePairs)) {
                $KeyAst = $Entry.Item1
                if (-not $KeyAst) {
                    continue
                }

                $KeyName = if ($KeyAst -is [StringConstantExpressionAst]) {
                    $KeyAst.Value
                } else {
                    $KeyAst.Extent.Text.Trim('"', "'")
                }

                if ([string]::IsNullOrWhiteSpace($KeyName)) {
                    continue
                }

                if (-not $AvailableStateMap.ContainsKey($KeyName)) {
                    $AvailableStateMap[$KeyName] = $KeyName
                }
            }
        }
    }

    $AvailableStates = @($AvailableStateMap.Values)
    if ($AvailableStates.Count -eq 0) {
        Write-Debug 'Failed to find state keys in cursor command path'
        return
    }

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) { $WordToComplete = $WordToComplete.Trim($Quote) }

    # Find relevant matches, prioritizing those that start with the search term,
    # then alphabetically.
    $Completions = $AvailableStates |
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
                <# Tooltip #> "State"
            )
        }

    if ($Completions.Count -gt 0) { return $Completions }
    return $null  # Prevent fallback autocomplete
}
