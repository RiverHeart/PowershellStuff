using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Custom PSScriptAnalyzer rule to detect improper usage of the -is operator.

.DESCRIPTION
    This rule scans the provided script block for instances where the -is operator
    is used improperly. Specifically, instances where someone writes
    `-not (<expression> -is <type>)` pattern.

.EXAMPLE
    Test-ImproperIsUsage -ScriptBlockAst {
        if (-not ($x -is [int])) {
            Write-Output "Improper usage detected."
        }
    }.Ast

.EXAMPLE
    Test-ImproperIsUsage -FilePath .\Public\DSL\Styling\Resources.ps1

.EXAMPLE
    Use with PSScriptAnalyzer to enforce proper usage of the -is operator.

    Invoke-ScriptAnalyzer `
        -Path 'path/to/script.ps1' `
        -CustomRulePath 'path/to/Rules.psm1'
#>
function Test-ImproperIsUsage {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $FilePath
    )

    process {
        try {
            $FindAstNodeParams = @{
                Type = 'UnaryExpressionAst'
                Recurse = $true
                Query = {
                    param($AstNode)

                    $AstNode.TokenKind -eq 'Not' -and
                    $AstNode.Child -is [ParenExpressionAst] -and
                    $AstNode.Child.Pipeline.PipelineElements.Count -eq 1 -and
                    (
                        $AstNode.Child.Pipeline.PipelineElements[0].Expression -is [BinaryExpressionAst] -and
                        $AstNode.Child.Pipeline.PipelineElements[0].Expression.Operator -eq 'Is'
                    )
                }
            }

            if ($PSBoundParameters.ContainsKey('FilePath')) {
                $FindAstNodeParams.FilePath = $FilePath
            } elseif ($PSBoundParameters.ContainsKey('ScriptBlockAst')) {
                $FindAstNodeParams.Ast = $ScriptBlockAst
            } else {
                Write-Error 'Either ScriptBlockAst or FilePath is required.'
                return
            }

            Find-AstNode @FindAstNodeParams | ForEach-Object {
                [PSCustomObject]@{
                    Message = "Use '<expression> -isnot <type>' instead of '-not (<expression> -is <type>)'."
                    Extent = $_.Extent
                    RuleName = $PSCmdlet.MyInvocation.MyCommand.Name
                    Severity = 'Warning'
                    RuleSuppressionId = 'PSUseIsNotOperator'
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
