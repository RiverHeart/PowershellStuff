using namespace System.Collections.Generic
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Gets declared parameter names from a callable.

.DESCRIPTION
    Returns normalized parameter metadata for a scriptblock, function,
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

        $ScriptAst = if ($Callable -is [scriptblock]) {
            $Callable.Ast
        } elseif ($Callable -is [FunctionInfo]) {
            $Callable.ScriptBlock.Ast
        }

        if ($ScriptAst) {
            $ParamBlock = if ($ScriptAst -is [FunctionDefinitionAst]) {
                $ScriptAst.Body.ParamBlock
            } else {
                $ScriptAst.ParamBlock
            }
            if ($ParamBlock) {
                $CallableParameters = $ParamBlock.Parameters | ForEach-Object {
                    $ParameterAst = $_
                    $ParameterSets = [List[string]]::new()
                    $MandatoryParameterSets = [List[string]]::new()

                    foreach ($Attribute in $ParameterAst.Attributes |
                        Where-Object { $_.TypeName.Name -eq 'Parameter' }) {
                        $SetArgument = $Attribute.NamedArguments |
                            Where-Object { $_.ArgumentName -eq 'ParameterSetName' } |
                            Select-Object -First 1
                        $SetName = if ($SetArgument) {
                            [string] $SetArgument.Argument.SafeGetValue()
                        } else {
                            '__AllParameterSets'
                        }
                        if (-not $ParameterSets.Contains($SetName)) {
                            $ParameterSets.Add($SetName)
                        }

                        $MandatoryArgument = $Attribute.NamedArguments |
                            Where-Object { $_.ArgumentName -eq 'Mandatory' } |
                            Select-Object -First 1

                        $IsMandatory = if (
                            -not $MandatoryArgument -or
                            $MandatoryArgument.ExpressionOmitted
                        ) {
                            [bool] $MandatoryArgument
                        } else {
                            [bool] $MandatoryArgument.Argument.SafeGetValue()
                        }

                        if ($IsMandatory -and -not $MandatoryParameterSets.Contains($SetName)) {
                            $MandatoryParameterSets.Add($SetName)
                        }
                    }

                    if ($ParameterSets.Count -eq 0) {
                        $ParameterSets.Add('__AllParameterSets')
                    }

                    [pscustomobject] @{
                        PSTypeName = 'Nitpick.CallableParameter'
                        Name = $ParameterAst.Name.VariablePath.UserPath
                        ParameterType = $ParameterAst.StaticType
                        ParameterSets = $ParameterSets.ToArray()
                        MandatoryParameterSets = $MandatoryParameterSets.ToArray()
                    }
                }
            }
        } else {
            $CallableParameters = $Callable.Parameters.Values | ForEach-Object {
                $ParameterSets = [List[string]]::new()
                $MandatoryParameterSets = [List[string]]::new()
                foreach ($ParameterSet in $_.ParameterSets.Values) {
                    $ParameterSets.Add($ParameterSet.Name)
                    if ($ParameterSet.IsMandatory) {
                        $MandatoryParameterSets.Add($ParameterSet.Name)
                    }
                }
                if ($ParameterSets.Count -eq 0) {
                    $ParameterSets.Add('__AllParameterSets')
                }

                [pscustomobject] @{
                    PSTypeName = 'Nitpick.CallableParameter'
                    Name = $_.Name
                    ParameterType = $_.ParameterType
                    ParameterSets = $ParameterSets.ToArray()
                    MandatoryParameterSets = $MandatoryParameterSets.ToArray()
                }
            }
        }

        $CallableParameters | Where-Object {
            ([string]::IsNullOrEmpty($Name) -or $_.Name -like $Name) -and
            ([string]::IsNullOrEmpty($Type) -or $_.ParameterType.Name -eq $Type)
        }
    }
}
