<#
.SYNOPSIS
    Returns one or more AST nodes, optionally filterable by type.

.DESCRIPTION
    Lightweight local copy of GrabBag's Find-AstNode so AstEditor remains
    self-contained while still using consistent AST query semantics.
#>
function Find-AstNode {
    [CmdletBinding(DefaultParameterSetName = 'ByScriptBlock')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByScriptBlock', Position = 0)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory, ParameterSetName = 'ByAst', Position = 0)]
        [System.Management.Automation.Language.Ast] $Ast,

        [Parameter(ParameterSetName = 'ByScriptBlock', Position = 1)]
        [Parameter(ParameterSetName = 'ByAst', Position = 1)]
        [ArgumentCompleter({
                param(
                    [string] $CommandName,
                    [string] $ParameterName,
                    [string] $WordToComplete,
                    [System.Management.Automation.Language.CommandAst] $CommandAst,
                    [System.Collections.IDictionary] $FakeBoundParameters
                )

                if (-not $script:FindAstNodeCompletionCache) {
                    $script:FindAstNodeCompletionCache =
                    [System.Management.Automation.Language.Ast].Assembly.ExportedTypes |
                    Where-Object {
                        $_.BaseType -and (
                            $_.BaseType -eq [System.Management.Automation.Language.Ast] -or
                            $_.BaseType.IsSubclassOf([System.Management.Automation.Language.Ast])
                        )
                    } |
                    Select-Object -ExpandProperty Name |
                    Sort-Object
                }

                $Completions = $script:FindAstNodeCompletionCache |
                Where-Object {
                    $_.StartsWith($WordToComplete, [System.StringComparison]::InvariantCultureIgnoreCase)
                }

                if ($Completions.Count -gt 0) {
                    return $Completions
                }

                return $null
            })]
        [string[]] $Type,

        [scriptblock] $Query,

        [switch] $All,

        [switch] $Recurse
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
        $Ast = $ScriptBlock.Ast
    }

    $HasCallerQuery = $PSBoundParameters.ContainsKey('Query')
    $TypeNames = if ($Type) { $Type } else { @() }

    if ($HasCallerQuery) {
        $OriginalQuery = $Query

        # Pass to Foreach-Object so query scriptblocks can reference $_.
        $HasParamBlockParameters =
        $null -ne $OriginalQuery.Ast.ParamBlock -and
        $OriginalQuery.Ast.ParamBlock.Parameters.Count -gt 0

        if ($HasParamBlockParameters) {
            $EvaluateQuery = {
                param($AstNode)
                & $OriginalQuery $AstNode
            }
        } else {
            $EvaluateQuery = {
                param($AstNode)
                $AstNode | ForEach-Object $OriginalQuery
            }
        }
    }

    $Query = {
        param($AstNode)

        if ($TypeNames.Count -gt 0) {
            $IsExpectedType = $false
            foreach ($T in $TypeNames) {
                if ($AstNode.GetType().Name -eq $T) {
                    $IsExpectedType = $true
                    break
                }
            }

            if (-not $IsExpectedType) {
                return $false
            }
        }

        if ($HasCallerQuery) {
            return (& $EvaluateQuery $AstNode)
        }

        return $true
    }

    if ($All) {
        return $Ast.FindAll($Query, $Recurse)
    }

    return $Ast.Find($Query, $Recurse)
}
