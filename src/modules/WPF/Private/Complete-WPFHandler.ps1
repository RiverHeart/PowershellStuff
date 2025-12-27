function Complete-WPFHandler {
    [CmdletBinding()]
    [OutputType([string[]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(<#Category#> 'PSReviewUnusedParameter', Scope='Function', Justification='My little remaining sanity')]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
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
        Write-Host "2"
        Write-Debug 'Failed to find params for TabExpansion2'
        return
    }

    # Confusing. When typing `Handler X` the `Handler` function hasn't become
    # a CommandAst object yet. Once the Handler has a scriptblock defined
    # such as `Handler X {}` it becomes one. Therefore we need to get the last
    # CommandAst that isn't the handler itself to account for the two scenarios.
    $ParentNode = $Params.Ast.FindAll({
        param($AstNode)
        $AstNode -is [System.Management.Automation.Language.CommandAst] -and
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
        $Type = Get-WPFType $Control

        if (-not $Type) {
            Write-Debug "Failed to find type for control '$Control'"
            return
        }

        $script:WPFHandlerCache.Completions[$Control] = $Type.GetEvents().Name
    }

    # If no word to filter on, return all results
    if ([String]::IsNullOrEmpty($WordToComplete)) {
        return $script:WPFHandlerCache.Completions[$Control]
    }

    # Filter on WordToComplete
    return $script:WPFHandlerCache.Completions[$Control] |
        Where-Object {
            $_.StartsWith($WordToComplete, [System.StringComparison]::InvariantCultureIgnoreCase)
        }
}
