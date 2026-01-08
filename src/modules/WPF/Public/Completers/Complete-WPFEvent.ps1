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
    [OutputType([System.Management.Automation.CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    # Micro-optimization, maybe?
    if (-not $script:WPFHandlerCache) {
        $script:WPFHandlerCache = @{
            Completions = @{}
        }
    }

    # Obtain the raw arguments passed to TabExpansion2 so we can traverse
    # the AST ourselves.
    $Params = Get-WPFFunctionParam TabExpansion2
    if (-not $Params) {
        Write-Debug 'Failed to find params for TabExpansion2'
        return
    }

    # Confusing. When typing `Handler X` the `Handler` function hasn't become
    # a CommandAst object yet. Once the Handler has a scriptblock defined
    # such as `Handler X {}` it becomes one. Therefore we need to get the last
    # CommandAst that isn't the handler itself to account for the two scenarios.
    $ParentNode = $Params.Ast.FindAll({
        param($AstNode)
        $AstNode -is [CommandAst] -and
        $AstNode.Extent.StartOffset -le $Params.PositionOfCursor.Offset -and
        $Params.PositionOfCursor.Offset -le $AstNode.Extent.EndOffset
    }, <# recurse #> $True) |
        Where-Object { $_.GetCommandName() -ne 'Handler' } |
        Select-Object -Last 1

    # Validate parent node exists
    if (-not $ParentNode) {
        Write-Debug 'Failed to find parent node'
        return
    }

    # Use reflection to obtain control type and get the list of
    # supported events. Store in cache for future lookups.
    # TODO: Could use more validation here
    $Control = $ParentNode.GetCommandName()
    if (-not $script:WPFHandlerCache.Completions.ContainsKey($Control)) {
        $Type = Get-WPFTypeInfo $Control

        if (-not $Type) {
            Write-Debug "Failed to find type for control '$Control'"
            return
        }

        $script:WPFHandlerCache.Completions[$Control] = $Type.GetEvents().Name
    }

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) {
        $WordToComplete = $WordToComplete.Trim($Quote)
    }

    # The results are already alphabetical so no need to sort these.
    $Completions = $script:WPFHandlerCache.Completions[$Control] |
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
                <# Tooltip #> "Event"
            )
        }

    if ($Completions.Count -gt 0) {
        return $Completions
    }
    return $null  # Prevent fallback autocomplete
}
