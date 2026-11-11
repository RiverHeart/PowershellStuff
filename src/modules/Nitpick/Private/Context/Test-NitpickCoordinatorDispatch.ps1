using namespace System.Collections

<#
.SYNOPSIS
    Checks that invocation metadata was created by the coordinator helper.

.DESCRIPTION
    Requires the exact in-process token object and expected payload shape.
    This rejects accidental or ordinary caller-supplied metadata; it is not
    intended to defend against arbitrary code already running in the process.

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function Test-NitpickCoordinatorDispatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Dispatch
    )

    if ($Dispatch -isnot [IDictionary] -or
        $Dispatch.psbase.Count -ne 2 -or
        -not $Dispatch.Contains('Token') -or
        -not $Dispatch.Contains('Target')
    ) {
        return $false
    }

    return [object]::ReferenceEquals(
        $Dispatch.Token,
        [NitpickRule]::CoordinatorDispatchToken
    )
}
