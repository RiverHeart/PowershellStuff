<#
.SYNOPSIS
    Asserts a hook callable signature for a given hook type.

.DESCRIPTION
    Ensures the callable declares the required parameters used by TabCentral
    when invoking completer and modifier hooks.
#>
function Assert-TabCentralHookCallableSignature {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [object] $TargetCallable,

        [Parameter(Mandatory)]
        [ValidateSet('Completer', 'Modifier')]
        [string] $HookType
    )

    $RequiredParams = switch ($HookType) {
        'Completer' { @('inputScript', 'cursorColumn', 'ast', 'tokens', 'positionOfCursor', 'options') }
        'Modifier' { @('CommandCompletion') }
    }

    $CallableParams = Get-TabCentralHookCallableParameterName -TargetCallable $TargetCallable
    $MissingParams = @(
        $RequiredParams |
            Where-Object {
                $CallableParams -notcontains $_
            }
    )

    if ($MissingParams.Count -gt 0) {
        $CallableName = if ($TargetCallable -is [scriptblock]) {
            '<scriptblock>'
        } else {
            $TargetCallable.Name
        }

        $MissingParamDisplay = $MissingParams -join ', '
        $RequiredParamDisplay = $RequiredParams -join ', '
        throw (
            "Invalid $HookType hook callable '$CallableName'. " +
            "Missing required parameter(s): $MissingParamDisplay. " +
            "Expected parameter(s): $RequiredParamDisplay."
        )
    }
}
