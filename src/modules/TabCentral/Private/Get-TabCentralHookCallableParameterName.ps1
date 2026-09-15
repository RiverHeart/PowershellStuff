<#
.SYNOPSIS
    Gets declared parameter names from a hook callable.

.DESCRIPTION
    Returns the parameter names declared by a scriptblock, function, or cmdlet
    command info object.
#>
function Get-TabCentralHookCallableParameterName {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [object] $TargetCallable
    )

    if ($TargetCallable -is [scriptblock]) {
        $ParamBlock = $TargetCallable.Ast.ParamBlock
        if (-not $ParamBlock) {
            return @()
        }

        return @(
            $ParamBlock.Parameters |
                ForEach-Object {
                    $_.Name.VariablePath.UserPath
                }
        )
    }

    return @($TargetCallable.Parameters.Keys)
}
