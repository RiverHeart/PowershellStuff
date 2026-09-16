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
    Test-UseIsNotOperator -FilePath .\Public\DSL\Styling\Resources.ps1

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

            Find-WPFAstNode @FindAstNodeParams | ForEach-Object {
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
