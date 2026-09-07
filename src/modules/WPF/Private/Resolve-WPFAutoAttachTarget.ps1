<#
.SYNOPSIS
    Resolves the auto-attach parent for a control keyword, honoring an
    explicit per-call override.

.DESCRIPTION
    Centralizes the "should this control auto-attach, and to what" decision
    that used to be duplicated inline in every control keyword. Keywords pass
    their own -AutoAttach switch and $PSBoundParameters through unchanged;
    when -AutoAttach was explicitly bound to $false, this returns $null
    (suppressing auto-attach) regardless of the ambient WPFAutoAttachContext.
    Otherwise it falls through to the ambient context as before, so existing
    scripts that never pass -AutoAttach see no behavior change.

    An explicit override is preferred over nulling WPFAutoAttachContext in
    the caller's own scope, since that ambient variable can leak through
    ordinary (non-DSL-invoked) function calls the same way $this used to.
#>
function Resolve-WPFAutoAttachTarget {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $Cmdlet,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $BoundParameters,

        [switch] $AutoAttach
    )

    if ($BoundParameters.ContainsKey('AutoAttach') -and -not $AutoAttach) {
        return $null
    }

    return $Cmdlet.GetVariableValue('WPFAutoAttachContext')
}
