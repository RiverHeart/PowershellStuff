using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    PSScriptAnalyzer rule to detect instances of the '-not (<expression> -is <type>)' pattern.

.DESCRIPTION
    PSScriptAnalyzer rule to detect instances of the '-not (<expression> -is <type>)' pattern.

    The rule suggests using the '-isnot' operator instead of the '-not (<expression> -is <type>)'
    pattern.

    Native Nitpick findings contain two coordinated detached edits: remove the unary
    negation token and replace the type-test operator. Parentheses and trivia are retained.
    Redirected and background pipelines are diagnostic-only. ScriptAnalyzer receives
    diagnostics without suggested corrections because it cannot preserve change-set atomicity.

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
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord', 'PSCustomObject')]
    param(
        [Parameter(Mandatory, ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='Details')]
        [switch] $Details
    )

    begin {
        $Metadata = [pscustomobject]@{
            Name = 'UseIsNotOperator'
            Command = $PSCmdlet.MyInvocation.MyCommand.Name
            Category = 'Style'
            Description = 'Detects instances of the `-not (<expression> -is <type>)` pattern and suggests using the `-isnot` operator instead.'
            Severity = 'Information'
            Explanation = 'Using the `-isnot` operator is preferred over the `-not (<expression> -is <type>)` pattern for readability.'
        }
    }

    process {
        if ($Details) { return $Metadata }

        try {
            $MatchingExpressions = $ScriptBlockAst.FindAll({
                param($AstNode)

                $AstNode -is [UnaryExpressionAst] -and
                $AstNode.TokenKind -eq 'Not' -and
                $AstNode.Child -is [ParenExpressionAst] -and
                $AstNode.Child.Pipeline -is [PipelineAst] -and
                $AstNode.Child.Pipeline.PipelineElements.Count -eq 1 -and
                $AstNode.Child.Pipeline.PipelineElements[0] -is [CommandExpressionAst] -and
                (
                    $AstNode.Child.Pipeline.PipelineElements[0].Expression -is [BinaryExpressionAst] -and
                    $AstNode.Child.Pipeline.PipelineElements[0].Expression.Operator -eq 'Is'
                )
            }, $false <# Do not enter nested script blocks; ScriptAnalyzer analyzes those scopes separately. #>)

            $Tokens = $null
            if ($MatchingExpressions.Count -gt 0) {
                $Source = $ScriptBlockAst.Extent.StartScriptPosition.GetFullScript()
                $ParseErrors = $null
                [void] [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
                # Interpolated-string subexpressions store their tokens separately.
                $PendingTokens = [System.Collections.Generic.Queue[Token]]::new()
                $AllTokens = [System.Collections.Generic.List[Token]]::new()
                foreach ($Token in $Tokens) {
                    $PendingTokens.Enqueue($Token)
                }
                while ($PendingTokens.Count -gt 0) {
                    $Token = $PendingTokens.Dequeue()
                    $AllTokens.Add($Token)
                    if ($Token -is [StringExpandableToken]) {
                        foreach ($NestedToken in $Token.NestedTokens) {
                            $PendingTokens.Enqueue($NestedToken)
                        }
                    }
                }
                $Tokens = $AllTokens.ToArray()
            }

            $MatchingExpressions | ForEach-Object {
                $BadNode = $_
                $Pipeline = $BadNode.Child.Pipeline
                $CommandExpression = $Pipeline.PipelineElements[0]
                $Binary = $CommandExpression.Expression
                $FilePath = if ($BadNode.Extent.File) { $BadNode.Extent.File } else { '<ScriptBlock>' }
                $Corrections = @()

                # Outer -not observes redirected output or a job, not the Boolean type
                # test result, so moving negation inside those pipelines is unsafe.
                $IsBackground = $Pipeline.PSObject.Properties['Background'] -and $Pipeline.Background
                if ($CommandExpression.Redirections.Count -eq 0 -and -not $IsBackground) {
                    $Negation = @($Tokens | Where-Object {
                        $_.Kind -eq [TokenKind]::Not -and
                            $_.Extent.StartOffset -eq $BadNode.Extent.StartOffset -and
                            $_.Extent.EndOffset -le $BadNode.Child.Extent.StartOffset
                    })
                    $Operator = @($Tokens | Where-Object {
                        $_.Kind -eq [TokenKind]::Is -and
                            $_.Extent.StartOffset -ge $Binary.Left.Extent.EndOffset -and
                            $_.Extent.EndOffset -le $Binary.Right.Extent.StartOffset
                    })
                    if ($Negation.Count -ne 1 -or $Operator.Count -ne 1) {
                        throw "Rule '$($Metadata.Name)' could not uniquely locate the negation and type-test tokens at offsets [$($BadNode.Extent.StartOffset), $($BadNode.Extent.EndOffset))."
                    }

                    $ChangeSetId = '{0}:{1}:{2}' -f $Metadata.Name, $BadNode.Extent.StartOffset, $BadNode.Extent.EndOffset
                    $Edits = @(
                        New-AstTextEdit `
                            -Extent $Negation[0].Extent `
                            -ReplacementText '' `
                            -Reason 'Remove unary negation from the type test.'
                        New-AstTextEdit `
                            -Extent $Operator[0].Extent `
                            -ReplacementText '-isnot' `
                            -Reason "Use '-isnot' to negate the type test."
                    )
                    $Corrections = @(
                        foreach ($Edit in $Edits) {
                            New-NitpickCorrection `
                                -TextEdit $Edit `
                                -FilePathOrContext $FilePath `
                                -Description $Edit.Reason `
                                -RuleName $Metadata.Name `
                                -Applicability Safe `
                                -ChangeSetId $ChangeSetId
                        }
                    )
                }

                New-NitpickFinding `
                    -RuleName $Metadata.Name `
                    -Message "Uses '-not (<expression> -is <type>)' instead of '<expression> -isnot <type>'." `
                    -ViolationExtent $BadNode.Extent `
                    -Severity $Metadata.Severity `
                    -RuleSuppressionID $Metadata.Name `
                    -Corrections $Corrections `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
