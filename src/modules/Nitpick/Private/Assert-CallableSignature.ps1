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
        [string[]] $OptionalParams = @()
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
}
