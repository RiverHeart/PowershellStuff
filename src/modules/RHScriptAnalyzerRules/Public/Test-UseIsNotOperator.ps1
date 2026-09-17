using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    PSScriptAnalyzer rule to detect instances of the '-not (<expression> -is <type>)' pattern.

.DESCRIPTION
    PSScriptAnalyzer rule to detect instances of the '-not (<expression> -is <type>)' pattern.

    The rule suggests using the '-isnot' operator instead of the '-not (<expression> -is <type>)'
    pattern.

.EXAMPLE
    Test-UseIsNotOperator -ScriptBlockAst {
        if (-not ($x -is [int])) {
            Write-Output "Improper usage detected."
        }
    }.Ast

.EXAMPLE
    Combine with Invoke-ScriptAnalyzer.

    Invoke-ScriptAnalyzer `
        -Path 'path/to/script.ps1' `
        -CustomRulePath 'path/to/Rules.psm1'
#>
function Test-UseIsNotOperator {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst
    )

    process {
        try {
            $MatchingExpressions = $ScriptBlockAst.FindAll({
                param($AstNode)

                $AstNode -is [UnaryExpressionAst] -and
                $AstNode.TokenKind -eq 'Not' -and
                $AstNode.Child -is [ParenExpressionAst] -and
                $AstNode.Child.Pipeline.PipelineElements.Count -eq 1 -and
                (
                    $AstNode.Child.Pipeline.PipelineElements[0].Expression -is [BinaryExpressionAst] -and
                    $AstNode.Child.Pipeline.PipelineElements[0].Expression.Operator -eq 'Is'
                )
            }, $false <# DO NOT RECURSE, you will get duplicate matches from Invoke-ScriptAnalyzer #>)

            $MatchingExpressions | ForEach-Object {
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
