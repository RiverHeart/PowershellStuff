using namespace System.Collections

<#
.SYNOPSIS
    Creates the internal marker for coordinator-owned rule invocation metadata.

.DESCRIPTION
    The unique token distinguishes the coordinator's private handoff from an
    ordinary invocation-parameters dictionary. It is an in-process capability
    marker, not a security boundary against arbitrary code running in the process.

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function New-NitpickCoordinatorDispatch {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Target
    )

    return @{
        Token = [NitpickRule]::CoordinatorDispatchToken
        Target = $Target
    }
}
