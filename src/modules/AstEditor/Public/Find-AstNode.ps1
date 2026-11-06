using namespace System
using namespace System.Management.Automation.Language

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

.EXAMPLE
    Find all nodes in a file of a given type and range.

    Find-AstNode `
        -FilePath .\path\to\file.ps1 `
        -Type UnaryExpressionAst `
        -Range @(10, 20)

.PARAMETER Query
    Filters candidate nodes. The query may emit zero or one value; zero is treated as false.
    Emitting multiple values causes an error because it is ambiguous when converted to Boolean.

.PARAMETER Document
    Searches the submitted AST of an existing document without reparsing it.

.PARAMETER Range
    Limits results to nodes fully contained in a zero-based, end-exclusive range.
    Accepts an IScriptExtent or an array of two Int32 offsets. This is containment,
    not overlap; enclosing nodes are not returned merely because they span the range.
#>
function Find-AstNode {
    [CmdletBinding(DefaultParameterSetName='ByTabExpansion2Context')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=0)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory,ParameterSetName='ByAst',Position=0)]
        [System.Management.Automation.Language.Ast] $Ast,

        [Parameter(Mandatory,ParameterSetName='ByDocument',Position=0)]
        [AstDocument] $Document,

        [Parameter(Mandatory,ParameterSetName='ByFilePath',Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $FilePath,

        [Parameter(ParameterSetName='ByScriptBlock',Position=1)]
        [Parameter(ParameterSetName='ByAst',Position=1)]
        [Parameter(ParameterSetName='ByDocument',Position=1)]
        [Parameter(ParameterSetName='ByFilePath',Position=1)]
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
        [Parameter(ParameterSetName='ByDocument')]
        [Parameter(ParameterSetName='ByFilePath')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [scriptblock] $Query,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByDocument')]
        [Parameter(ParameterSetName='ByFilePath')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [switch] $All,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByDocument')]
        [Parameter(ParameterSetName='ByFilePath')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [switch] $Recurse,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByDocument')]
        [Parameter(ParameterSetName='ByFilePath')]
        [Parameter(Mandatory,ParameterSetName='ByTabExpansion2Context')]
        [switch] $ContainsCursor,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByDocument')]
        [Parameter(ParameterSetName='ByFilePath')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [int] $CursorOffset,

        # NOTE: Regarding the acceptance of an integer array for the Range parameter,
        # PowerShell 5.1 does not support `System.Range` and it would still need
        # similar validation.
        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByDocument')]
        [Parameter(ParameterSetName='ByFilePath')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [object] $Range
    )

    $HasRange = $PSBoundParameters.ContainsKey('Range')
    if ($HasRange) {
        if ($Range -is [IScriptExtent]) {
            $StartOffset = $Range.StartOffset
            $EndOffset = $Range.EndOffset
        } elseif ($Range -is [Array] -and $Range.Rank -eq 1 -and $Range.Count -eq 2 -and
            $Range[0] -is [int] -and $Range[1] -is [int]
        ) {
            $StartOffset = $Range[0]
            $EndOffset = $Range[1]
        } else {
            Write-Error `
                -Message 'Range must be an IScriptExtent or an array of two Int32 offsets.' `
                -Category InvalidArgument
            return
        }

        if ($StartOffset -lt 0 -or $EndOffset -lt $StartOffset) {
            Write-Error `
                -Message 'Range offsets must be non-negative and the end must not precede the start.' `
                -Category InvalidArgument
            return
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
        $Ast = $ScriptBlock.Ast
    } elseif ($PSCmdlet.ParameterSetName -eq 'ByDocument') {
        $Ast = $Document.Ast
    } elseif ($PSCmdlet.ParameterSetName -eq 'ByFilePath') {
        $ResolvedFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
        $null = $tokens = $errors = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseFile($ResolvedFilePath, [ref] $tokens, [ref] $errors)
    }

    $HasContainsCursor = $PSBoundParameters.ContainsKey('ContainsCursor')
    $HasCursorOffset = $PSBoundParameters.ContainsKey('CursorOffset')

    if ($HasContainsCursor -and ((-not $HasCursorOffset) -or $null -eq $Ast)) {
        $TabExpansion2Params = $null
        $Callstack = Get-PSCallStack | Where-Object { $_.Command -eq 'TabExpansion2' } | Select-Object -First 1
        if ($Callstack) {
            $TabExpansion2Params = $Callstack.InvocationInfo.BoundParameters
        }

        if ($null -eq $Ast -and $TabExpansion2Params -and $TabExpansion2Params.Ast) {
            $Ast = $TabExpansion2Params.Ast
        }

        if ($TabExpansion2Params -and
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

                # Pass to Foreach-Object so query scriptblocks can reference $_.
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

        if ($HasRange) {
            if ($AstNode.Extent.StartOffset -lt $StartOffset -or
                $AstNode.Extent.EndOffset -gt $EndOffset
            ) {
                return $false
            }
        }

        if ($HasCallerQuery) {
            $QueryOutput = @(& $EvaluateQuery $AstNode)
            $QueryOutputTypes = if ($QueryOutput.Count -eq 0) {
                '<none>'
            } else {
                ($QueryOutput | ForEach-Object { $_.GetType().FullName }) -join ', '
            }

            Write-Debug ("Query for AST node type '{0}' emitted {1} value(s): {2}" -f
                $AstNode.GetType().Name,
                $QueryOutput.Count,
                $QueryOutputTypes)

            if ($QueryOutput.Count -gt 1) {
                throw "Find-AstNode query emitted $($QueryOutput.Count) values for '$($AstNode.GetType().Name)': $QueryOutputTypes. The query must emit at most one value."
            }

            if ($QueryOutput.Count -eq 0) {
                return $false
            }

            return [bool] $QueryOutput[0]
        }

        return $true
    }

    $Result = if ($All) {
        $Ast.FindAll($Query, $Recurse)
    } else {
        $Ast.Find($Query, $Recurse)
    }

    if ($null -ne $Result) {
        $Result
    }
}
