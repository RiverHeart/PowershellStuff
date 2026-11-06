<#
.SYNOPSIS
    Asserts a callable's signature.

.DESCRIPTION
    Asserts a callable's signature.
#>
function Assert-CallableSignature {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [object] $Callable,

        [string[]] $RequiredParams = @(),
        [string[]] $OptionalParams = @(),
        [string[]] $DispatchTypes = @()
    )

    $CallableParamNames = @(
        Get-CallableParameter -Callable $Callable |
            Select-Object -ExpandProperty Name
    )
    $MissingParams = @(
        $RequiredParams |
            Where-Object { $CallableParamNames -notcontains $_ }
    )

    if ($MissingParams.Count -gt 0) {
        $CallableName =
            if ($Callable -is [scriptblock]) { '<scriptblock>'}
            else { $Callable.Name }

        $MissingParamDisplay = $MissingParams -join ', '
        $RequiredParamDisplay = $RequiredParams -join ', '
        throw (
            "Invalid callable '$CallableName'. " +
            "Missing required parameter(s): $MissingParamDisplay. " +
            "Expected parameter(s): $RequiredParamDisplay."
        )
    }

    if ($DispatchTypes.Count -le 0) { return }

    $DispatchParameters = Get-CallableParameter -Callable $Callable |
        Where-Object {
            $_.Name -eq 'ScriptBlockAst' -or
            $_.ParameterType.Name -in $DispatchTypes
        }

    if ($DispatchParameters.Count -ne 1) {
        $CallableName =
            if ($Callable -is [scriptblock]) { '<scriptblock>'}
            else { $Callable.Name }

        $DispatchTypeDisplay = $DispatchTypes -join ' or '
        throw (
            "Invalid callable '$CallableName'. Expected exactly one dispatch parameter " +
            "named ScriptBlockAst or typed as $DispatchTypeDisplay; found $($DispatchParameters.Count)."
        )
    }
}
