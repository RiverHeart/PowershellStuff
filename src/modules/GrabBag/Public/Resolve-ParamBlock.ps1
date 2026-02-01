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
    [OutputType([RuntimeDefinedParameterDictionary])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptblock',Position=0)]
        [scriptblock] $ParamBlock,

        [Parameter(Mandatory,ParameterSetName='ByParameterAst',Position=0)]
        [ReadOnlyCollection[ParameterAst]] $ParameterAsts
    )

    if (-not $ParameterAsts) {
        $ParameterAsts = $ParamBlock.Ast.ParamBlock.Parameters
    }

    $Parameters = [RuntimeDefinedParameterDictionary]::new()
    foreach($ParameterAst in $ParameterAsts) {
        $Attributes = [List`1[System.Attribute]]::new()
        foreach($AttributeAst in $ParameterAst.Attributes) {
            if ($AttributeAst.GetType().Name -eq 'TypeConstraintAst') {
                # This is available already from ParameterAst
                continue
            }
            $TypeName = $AttributeAst.TypeName
            $AttributeType = $TypeName.GetReflectionAttributeType()
            $AttributeObj = $AttributeType::new()
            foreach($NamedArg in $AttributeAst.NamedArguments) {
                $AttributeObj.psobject.properties |
                    Where-Object { $_.Name -eq $NamedArg.ArgumentName } |
                    ForEach-Object {
                        if ($NamedArg.ExpressionOmitted) {
                            $_.Value = $True
                        } else {
                            $_.Value = $NamedArg.Argument
                        }
                    }
            }
            $Attributes.Add($AttributeObj)
        }
        $Parameter = [RuntimeDefinedParameter]::new($ParameterAst.Name.VariablePath, $ParameterAst.StaticType, $Attributes)
        if ($ParameterAst.DefaultValue) {
            $Parameter.Value = $Parameter.DefaultValue
        }
        $Parameters.Add($Parameter.Name, $Parameter)
    }

    return $Parameters
}
