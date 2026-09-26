<#
.SYNOPSIS
    Gets declared parameter names from a callable.

.DESCRIPTION
    Returns the parameter names declared by a scriptblock, function,
    or cmdlet command info object.

.EXAMPLE
    Get all parameters from a callable.

    Get-CallableParameter -Callable $MyFunction

.EXAMPLE
    Get all parameters from a callable as a list of names.

    Get-CallableParameter -Callable $MyFunction -List

.EXAMPLE
    Get all parameters by name that match a wildcard pattern.

    Get-CallableParameter -Callable $MyFunction -Name "PartialParamName*"
#>
function Get-CallableParameter {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object] $Callable,

        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Type
    )

    process {
        $CallableParameters = @()

        if ($Callable -is [scriptblock]) {
            $ParamBlock = $Callable.Ast.ParamBlock
            if ($ParamBlock) {
                $CallableParameters = $ParamBlock.Parameters | ForEach-Object {
                    [pscustomobject] @{
                        PSTypeName = 'Nitpick.CallableParameter'
                        Name = $_.Name.VariablePath.UserPath
                        ParameterType = $_.StaticType
                    }
                }
            }
        } else {
            $CallableParameters = $Callable.Parameters.Values | ForEach-Object {
                [pscustomobject] @{
                    PSTypeName = 'Nitpick.CallableParameter'
                    Name = $_.Name
                    ParameterType = $_.ParameterType
                }
            }
        }

        $CallableParameters | Where-Object {
            ([string]::IsNullOrEmpty($Name) -or $_.Name -like $Name) -and
            ([string]::IsNullOrEmpty($Type) -or $_.ParameterType.Name -eq $Type)
        }
    }
}
