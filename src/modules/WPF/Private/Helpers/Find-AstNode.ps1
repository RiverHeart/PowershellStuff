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

.EXAMPLE
    Find all CommandAsts in the given scriptblock.

    Find-AstNode { Write-Host 'Foobar'; Get-Date } -Type CommandAst -All

.EXAMPLE
    Find a CommandAst with a specific command name using the Query parameter.

    Find-AstNode { Write-Host 'Foobar'; Get-Date } -Type CommandAst -Query {
        $_.GetCommandName() -eq 'Get-Date'
    }
#>
function Find-AstNode {
    [CmdletBinding(DefaultParameterSetName='ByTabExpansion2Context')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=0)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory,ParameterSetName='ByAst',Position=0)]
        [System.Management.Automation.Language.Ast] $Ast,

        [Parameter(ParameterSetName='ByScriptBlock',Position=1)]
        [Parameter(ParameterSetName='ByAst',Position=1)]
        [Parameter(ParameterSetName='ByTabExpansion2Context',Position=1)]
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
            return @()  # Prevent fallback autocomplete
        })]
        [string[]] $Type,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [scriptblock] $Query,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [switch] $All,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [switch] $Recurse,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(Mandatory,ParameterSetName='ByTabExpansion2Context')]
        [switch] $ContainsCursor,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [int] $CursorOffset
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
        $Ast = $ScriptBlock.Ast
    }

    $HasContainsCursor = $PSBoundParameters.ContainsKey('ContainsCursor')
    $HasCursorOffset = $PSBoundParameters.ContainsKey('CursorOffset')

    if ($HasContainsCursor -and ((-not $HasCursorOffset) -or (-not $PSBoundParameters.ContainsKey('Ast')))) {
        $TabExpansion2Params = $null
        $Callstack = Get-PSCallStack | Where-Object { $_.Command -eq 'TabExpansion2' } | Select-Object -First 1
        if ($Callstack) {
            $TabExpansion2Params = $Callstack.InvocationInfo.BoundParameters
        }

        if ((-not $PSBoundParameters.ContainsKey('Ast')) -and $TabExpansion2Params -and $TabExpansion2Params.Ast) {
            $Ast = $TabExpansion2Params.Ast
        }

        if (
            $TabExpansion2Params -and
            $TabExpansion2Params.PositionOfCursor -and
            $null -ne $TabExpansion2Params.PositionOfCursor.Offset
        ) {
            $CursorOffset = [int] $TabExpansion2Params.PositionOfCursor.Offset
            $HasCursorOffset = $true
        }

        if (-not $HasCursorOffset) {
            Write-Error 'CursorOffset is required when ContainsCursor is specified and could not be resolved from TabExpansion2 context.'
            return
        }

        if (-not $Ast) {
            Write-Error 'Ast is required and could not be resolved from TabExpansion2 context.'
            return
        }
    }

    if ($HasCursorOffset -and -not $HasContainsCursor) {
        Write-Error 'ContainsCursor is required when CursorOffset is specified.'
        return
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

        if ($HasContainsCursor) {
            if ($CursorOffset -lt $AstNode.Extent.StartOffset -or
                $CursorOffset -gt $AstNode.Extent.EndOffset
            ) {
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
