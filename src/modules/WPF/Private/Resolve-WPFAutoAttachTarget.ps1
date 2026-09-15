<#
.SYNOPSIS
    Resolves the auto-attach parent for a control keyword, honoring an
    explicit per-call override.

.DESCRIPTION
    Centralizes the "should this control auto-attach, and to what" decision
    that used to be duplicated inline in every control keyword. Keywords pass
    their own -AutoAttach value and $PSBoundParameters through unchanged.
    Unlike -Confirm/-WhatIf, -AutoAttach doesn't trigger a behavior by its own
    presence - the ambient WPFAutoAttachContext is what drives attachment, so
    -AutoAttach is a value (the target itself, or $null to mean "none")
    rather than a switch: omitted, it defers to the ambient context; passed
    explicitly (including as $null), it replaces the ambient context outright
    - $null suppresses auto-attach, a real object attaches there directly.

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

        [AllowNull()]
        [object] $AutoAttach
    )

    if ($BoundParameters.ContainsKey('AutoAttach')) {
        return $AutoAttach
    }

    return $Cmdlet.GetVariableValue('WPFAutoAttachContext')
}

