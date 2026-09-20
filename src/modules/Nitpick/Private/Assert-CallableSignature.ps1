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
        [object] $TargetCallable,

        [hashtable] $RequiredParams = @{},
        [hashtable] $OptionalParams = @{}
    )

    $CallableParams = Get-CallableParameter -TargetCallable $TargetCallable -Name
    $MissingParams = $RequiredParams | Where-Object { $CallableParams -notcontains $_ }

    if ($MissingParams.Count -gt 0) {
        $CallableName =
            if ($TargetCallable -is [scriptblock]) { '<scriptblock>'}
            else { $TargetCallable.Name }

        $MissingParamDisplay = $MissingParams -join ', '
        $RequiredParamDisplay = $RequiredParams -join ', '
        Write-Error (
            "Invalid callable '$CallableName'. " +
            "Missing required parameter(s): $MissingParamDisplay. " +
            "Expected parameter(s): $RequiredParamDisplay."
        )
        return
    }
}
