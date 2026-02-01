<#
.SYNOPSIS
    Returns one or more AstNodes, filterable by types.

.NOTES
    Prior Art:
        Apparently there's a `Find-Ast` cmdlet in PowershellEditorServices.Command
        which gets loaded by VSCode and probably ISE as well.

.EXAMPLE
    Find the CommandAst in the given scriptblock.

    Find-AstNode { Write-Host 'Foobar' } -Type CommandAst
#>
function Find-AstNode {
    [CmdletBinding(DefaultParameterSetName='ByScriptBlock')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=0)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory,ParameterSetName='ByAst',Position=0)]
        [System.Management.Automation.Language.Ast] $Ast,

        [Parameter(ParameterSetName='ByScriptBlock',Position=1)]
        [Parameter(ParameterSetName='ByAst',Position=1)]
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
                    $_.StartsWith($WordToComplete, [StringComparison]::InvariantCultureIgnoreCase)
                }

            if ($Completions.Count -gt 0) {
                return $Completions
            }
            return $null  # Prevent fallback autocomplete
        })]
        [string[]] $Type,
        [scriptblock] $Query,
        [switch] $All,
        [switch] $Recurse
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
        $Ast = $ScriptBlock.Ast
    }

    if (-not $Query) {
        $Query = {
            param($AstNode)
            if ($Type) {
                foreach($T in $Type) {
                    if ($AstNode.GetType().Name -eq $T) {
                        $true
                        break
                    }
                }
            } else {
                $true  # Return everything
            }
        }
    }

    if ($All) {
        return $Ast.FindAll($Query, $Recurse)
    }

    return $Ast.Find($Query, $Recurse)
}
