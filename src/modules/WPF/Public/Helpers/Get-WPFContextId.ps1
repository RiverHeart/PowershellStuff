<#
.SYNOPSIS
    Returns the current WPF control context id.

.DESCRIPTION
    Resolves the current context using an explicit input object, the current
    DSL object ($this), the active context, or the single existing context,
    then returns that context id.

.EXAMPLE
    Get-WPFContextId

.EXAMPLE
    $ContextId = Get-WPFContextId -InputObject $Button
#>
function Get-WPFContextId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object] $InputObject
    )

    $ScopeObject = if ($PSBoundParameters.ContainsKey('InputObject')) {
        $InputObject
    } else {
        $PSCmdlet.GetVariableValue('this')
    }

    if ($ScopeObject) {
        $ObjectContextId = Get-WPFControlContextId -InputObject $ScopeObject
        if ($ObjectContextId) {
            return $ObjectContextId
        }
    }

    $ResolvedContextId = Resolve-WPFControlContextId
    if ($ResolvedContextId) {
        return $ResolvedContextId
    }

    Write-Error 'No current context id is available.'
}
