using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

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
function Complete-WPFEvent {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    # Micro-optimization, maybe?
    if (-not $script:WPFControlEventsCache) {
        $script:WPFControlEventsCache = @{
            Completions = @{}
        }
    }

    # While typing `Command <Parameter>`, the parser behavior changes as input grows:
    # `Command` may not yet be represented as a CommandAst, but `Command <Parameter>` is.
    #
    # Once that happens, the command under the cursor can resolve to `Command`
    # instead of the owning control (for example `Window` or `Button`). Ignore
    # the command names and aliases of consumers so selection stays on the enclosing
    # control.
    $IgnoredCommandNames = @('on', '-on', 'add-wpfhandler')

    try {
        $ParentNode = Find-AstNode -Type CommandAst -All -Recurse -ContainsCursor -Query {
            $CandidateName = $_.GetCommandName()
            $CandidateName -and ($IgnoredCommandNames -notcontains $CandidateName.ToLowerInvariant())
        } |
        Select-Object -Last 1
    } catch {
        Write-Debug "Failed to resolve AST context for event completion: $($_.Exception.Message)"
        return
    }

    # Validate parent node exists
    if (-not $ParentNode) {
        Write-Debug 'Failed to find parent node'
        return
    }

    # Use reflection to obtain control type and get the list of
    # supported events. Store in cache for future lookups.
    # TODO: Could use more validation here
    $Control = $ParentNode.GetCommandName()
    if ($Control -ieq 'App') { $Control = 'Window' }

    if (-not $script:WPFControlEventsCache.Completions.ContainsKey($Control)) {
        $Type = Get-WPFTypeInfo $Control

        if (-not $Type) {
            Write-Debug "Failed to find type for control '$Control'"
            return
        }

        $script:WPFControlEventsCache.Completions[$Control] = $Type.GetEvents().Name
    }

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) { $WordToComplete = $WordToComplete.Trim($Quote) }

    # The results are already alphabetical so no need to sort these.
    $Completions = $script:WPFControlEventsCache.Completions[$Control] |
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
                <# Tooltip #> "Event"
            )
        }

    if ($Completions.Count -gt 0) { return $Completions }
    return $null  # Prevent fallback autocomplete
}
