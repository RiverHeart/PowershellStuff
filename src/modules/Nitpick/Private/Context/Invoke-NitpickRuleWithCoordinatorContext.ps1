using namespace System.Collections

<#
.SYNOPSIS
    Invokes a rule against candidate text using the original coordinator-owned identity.

.DESCRIPTION
    Candidate documents are in-memory snapshots. This private dispatch path retains
    the identity of the original submitted target without making it caller-overridable.
    The coordinator marker is removed by NitpickRule before the rule callable runs.

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function Invoke-NitpickRuleWithCoordinatorContext {
    [CmdletBinding()]
    [OutputType([NitpickRuleInvocationResult])]
    param(
        [Parameter(Mandatory)]
        [NitpickRule] $Rule,

        [Parameter(Mandatory)]
        [object] $Target,

        [Parameter(Mandatory)]
        [IDictionary] $Context,

        [Parameter(Mandatory)]
        [object] $ContextTarget
    )

    $Parameters = @{
        Context = $Context
        __NitpickCoordinatorDispatch = New-NitpickCoordinatorDispatch -Target $ContextTarget
    }
    $Parameters[$Rule.DispatchParameterName] = $Target

    return $Rule.InvokeWithResult($Parameters)
}
