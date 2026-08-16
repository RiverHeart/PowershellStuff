using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Resolves the ParamBlock in a given Scriptblock or a list
    of ParameterAst into a RuntimeParameterDictionary.

.EXAMPLE
    Resolve-ParamBlock {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string] $Name = 'foo'
        )
    }
#>
function Resolve-ParamBlock {
    [CmdletBinding(DefaultParameterSetName='ByScriptblock')]
    [OutputType([System.Management.Automation.RuntimeDefinedParameterDictionary])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptblock',Position=0)]
        [scriptblock] $ParamBlock,

        [Parameter(Mandatory,ParameterSetName='ByParameterAst',Position=0)]
        [System.Collections.ObjectModel.ReadOnlyCollection[
            System.Management.Automation.Language.ParameterAst
        ]] $ParameterAsts,

        [string] $DefaultParameterSetName
    )

    if (-not $ParameterAsts) {
        $ParameterAsts = $ParamBlock.Ast.ParamBlock.Parameters
    }

    $Parameters = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    foreach ($ParameterAst in $ParameterAsts) {
        $Attributes = [List`1[System.Attribute]]::new()
        foreach ($AttributeAst in $ParameterAst.Attributes) {
            if ($AttributeAst.GetType().Name -eq 'TypeConstraintAst') {
                # This is available already from ParameterAst
                continue
            }
            $TypeName = $AttributeAst.TypeName
            $AttributeType = $TypeName.GetReflectionAttributeType()
            # Recreate each attribute from constant AST values so aliases and validation metadata
            # participate in PowerShell's normal dynamic parameter binding.
            [object[]] $PositionalArguments = @(
                foreach ($PositionalArgument in $AttributeAst.PositionalArguments) {
                    $PositionalArgument.SafeGetValue()
                }
            )
            $AttributeObj = [Activator]::CreateInstance($AttributeType, $PositionalArguments)
            foreach ($NamedArg in $AttributeAst.NamedArguments) {
                $AttributeObj.psobject.properties |
                    Where-Object { $_.Name -eq $NamedArg.ArgumentName } |
                    ForEach-Object {
                        if ($NamedArg.ExpressionOmitted) {
                            $_.Value = $True
                        } else {
                            $_.Value = $NamedArg.Argument.SafeGetValue()
                        }
                    }
            }
            $Attributes.Add($AttributeObj)
        }
        # A dynamic parameter without ParameterAttribute is not available in a named parameter set.
        if (-not [string]::IsNullOrEmpty($DefaultParameterSetName) -and
            -not ($Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
        ) {
            $ParameterAttribute = [System.Management.Automation.ParameterAttribute]::new()
            $ParameterAttribute.ParameterSetName = $DefaultParameterSetName
            $Attributes.Add($ParameterAttribute)
        }
        # Leave defaults unset here so the task evaluates its own defaults in its execution scope.
        $Parameter = [System.Management.Automation.RuntimeDefinedParameter]::new(
            $ParameterAst.Name.VariablePath,
            $ParameterAst.StaticType,
            $Attributes
        )
        $Parameters.Add($Parameter.Name, $Parameter)
    }

    return $Parameters
}
