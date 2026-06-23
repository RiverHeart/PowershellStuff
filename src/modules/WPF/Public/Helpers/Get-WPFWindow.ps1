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
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $ScopeObject = $null

    if (-not $PSBoundParameters.ContainsKey('ContextId')) {
        Write-Debug 'Get-WPFWindow: Resolving window for current context.'
        $ScopeObject = $PSCmdlet.GetVariableValue('this')
        if ($ScopeObject -is [System.Windows.Window]) {
            return $ScopeObject
        } elseif ($ScopeObject -and $ScopeObject -isnot [System.Windows.Window]) {
            Write-Debug "Get-WPFWindow: Current scope object is of type '$($ScopeObject.GetType().FullName)'."
        } else {
            Write-Debug 'Get-WPFWindow: No current scope object available; falling back to registry resolution.'
        }
    }

    Write-Debug "Get-WPFWindow: Resolving window for context '$ContextId'."

    if ($PSBoundParameters.ContainsKey('ContextId')) {
        if (-not (Test-WPFControlContextId -ContextId $ContextId -ErrorIfMissing)) {
            return
        }

        $ResolvedContextId = $ContextId
    } else {
        $ResolveContextParams = @{}
        if ($ScopeObject -and (Get-WPFControlContextId -InputObject $ScopeObject)) {
            $ResolveContextParams.InputObject = $ScopeObject
        }

        $ResolvedContextId = Resolve-WPFControlContextId @ResolveContextParams
    }

    if (-not $ResolvedContextId) {
        if ($PSBoundParameters.ContainsKey('ContextId')) {
            Write-Error 'No current window is available for the resolved context.'
        }
        return
    }

    $ControlTable = Get-WPFControlTable -ContextId $ResolvedContextId
    if (-not $ControlTable) {
        Write-Error "No control table found for context '$ResolvedContextId'."
        return
    }

    if ($ControlTable.ContainsKey('__WPFWindow')) {
        $RegisteredWindow = $ControlTable['__WPFWindow']
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
