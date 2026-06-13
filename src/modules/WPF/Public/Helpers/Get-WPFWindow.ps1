<#
.SYNOPSIS
    Returns the current window for the resolved WPF control context.

.DESCRIPTION
    Resolves the current context using explicit ContextId, the current DSL
    object ($this), active context, or the single existing context, then
    returns the root window registered for that context.

.EXAMPLE
    Get-WPFWindow

.EXAMPLE
    Get-WPFWindow -ContextId $ContextId
#>
function Get-WPFWindow {
    [CmdletBinding()]
    [OutputType([System.Windows.Window])]
    param(
        [string] $ContextId
    )

    $ScopeObject = $PSCmdlet.GetVariableValue('this')
    if ($ScopeObject -is [System.Windows.Window]) {
        return $ScopeObject
    }

    $ResolvedContextId = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $ScopeObject
    if (-not $ResolvedContextId) {
        Write-Error 'No current window is available for the resolved context.'
        return
    }

    $ControlTable = Get-WPFControlTable -ContextId $ResolvedContextId
    if (-not $ControlTable) {
        Write-Error "No control table found for context '$ResolvedContextId'."
        return
    }

    if ($ControlTable.ContainsKey('__WPFCurrentWindow')) {
        $RegisteredWindow = $ControlTable['__WPFCurrentWindow']
        if ($RegisteredWindow -is [System.Windows.Window]) {
            return $RegisteredWindow
        }
    }

    $WindowMatches = @(
        $ControlTable.Values |
            Where-Object { $_ -is [System.Windows.Window] }
    )

    if ($WindowMatches.Count -eq 1) {
        return $WindowMatches[0]
    }

    if ($WindowMatches.Count -gt 1) {
        Write-Error "Multiple windows exist in context '$ResolvedContextId'."
        return
    }

    Write-Error 'No current window is available for the resolved context.'
}
