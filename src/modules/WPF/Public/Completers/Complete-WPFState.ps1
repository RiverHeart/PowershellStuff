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
    There are some limitations to be aware of with this implementation:

    TODO:
    * This implementation is potentially expensive, especially for deeper command
      paths and larger ASTs. Caching results based on AST node extents may be a worthwhile
      optimization if performance becomes an issue. The cache would need to have a short
      expiration time (1 minute) or be cleared on AST-changing events to avoid stale results.
      Expiration time is probably the easier approach and would likely be sufficient given
      typical editing speeds. Honestly, I need some helper functions for cache management.

    * Currently, if multiple State commands are present in the command path, keys from
      all of them will be returned. Depending on the use case, it may be desirable to
      only return keys from the closest enclosing State command. This could be achieved by
      tracking the closest State node while traversing the AST path and only returning keys
      from that node.

    This is committed anyway so we have a baseline for functional behavior.

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
