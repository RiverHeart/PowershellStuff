function Complete-WPFHandler {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
    )

    if (-not $script:WPFHandlerCompleteStore) {
        $script:WPFHandlerCompleteStore = @{}
    }

    $Params = Get-FunctionParam TabExpansion2
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
        $AstNode -is [System.Management.Automation.Language.CommandAst] -and
        $AstNode.Extent.StartOffset -le $Params.PositionOfCursor.Offset -and
        $Params.PositionOfCursor.Offset -le $AstNode.Extent.EndOffset
    }, <# recurse #> $True) |
        Where-Object { $_.GetCommandName() -ne 'Handler' } |
        Select-Object -Last 1

    if (-not $ParentNode) {
        Write-Debug 'Failed to find parent node'
        return
    }

    # Filter supported controls and use reflection to get supported events.
    # Store results from future lookups.
    $Control = $ParentNode.GetCommandName()
    switch ($Control) {
        'Button' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Controls.Button].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        'DatePicker' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Controls.DatePicker].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        'Grid' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Controls.Grid].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        'Label' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Controls.Label].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        'StackPanel' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Controls.StackPanel].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        'TextBox' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Controls.TextBox].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        'Window' {
            if (-not $script:WPFHandlerCompleteStore.ContainsKey($Control)) {
                $script:WPFHandlerCompleteStore[$Control] = [System.Windows.Window].GetEvents().Name
            }
            return $script:WPFHandlerCompleteStore[$Control]
        }
        default {
            Write-Warning "Unsupported control '$Control'"
        }
    }
}
