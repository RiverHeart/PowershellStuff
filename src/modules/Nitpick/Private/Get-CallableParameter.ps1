<#
.SYNOPSIS
    Gets declared parameter names from a callable.

.DESCRIPTION
    Returns the parameter names declared by a scriptblock, function,
    or cmdlet command info object.
#>
function Get-CallableParameter {
    [CmdletBinding()]
    [OutputType([string[]], [object[]])]
    param (
        [Parameter(Mandatory)]
        [object] $TargetCallable,

        [switch] $Name
    )

    [object[]] $Result = @()

    if ($TargetCallable -is [scriptblock]) {
        $ParamBlock = $TargetCallable.Ast.ParamBlock
        if ($ParamBlock) {
            $Result = $ParamBlock.Parameters
        }
    } else {
        $Result = $TargetCallable.Parameters.Keys
    }

    if ($Name) {
        if ($TargetCallable -is [scriptblock]) {
            $Result = $Result | ForEach-Object { $_.Name.VariablePath.UserPath }
        } else {
            $Result = $Result | ForEach-Object { $_.ToString() }
        }
    }

    if ($Result.Count -gt 0) {
        return $Result
    }
}
