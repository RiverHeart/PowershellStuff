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
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([PSCustomObject[]], [pscustomobject])]
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
                $AstNode.Child.Pipeline.PipelineElements.Count -eq 1 -and
                (
                    $AstNode.Child.Pipeline.PipelineElements[0].Expression -is [BinaryExpressionAst] -and
                    $AstNode.Child.Pipeline.PipelineElements[0].Expression.Operator -eq 'Is'
                )
            }, $false <# Do not enter nested script blocks; ScriptAnalyzer analyzes those scopes separately. #>)

            $FilePath = if ($BadNode.Extent.FileName) {
                $BadNode.Extent.FileName
            } else {
                Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1 -ExpandProperty ScriptName
            }
            if (-not $FilePath) { $FilePath = '<ScriptBlock>' }

            $MatchingExpressions | ForEach-Object {
                $BadNode = $_
                $ReplacementText = $BadNode.Child.Pipeline.Extent.Text -replace '-is', '-isnot'

                $CorrectionExtent = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::new(
                    $BadNode.Extent.StartLineNumber,
                    $BadNode.Extent.EndLineNumber,
                    $BadNode.Extent.StartColumnNumber,
                    $BadNode.Extent.EndColumnNumber,
                    $ReplacementText,
                    $FilePath,  # File Path or Context
                    "Convert expression to '<expression> -isnot <type>'."  # Hover Text Description
                )
                $SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]]::new()
                $SuggestedCorrections.Add($CorrectionExtent)

                $DiagnosticRecord = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    Message = "Uses '-not (<expression> -is <type>)' instead of '<expression> -isnot <type>'."
                    Extent = $BadNode.Extent
                    RuleName = $Metadata.Name
                    Severity = $Metadata.Severity
                    RuleSuppressionId = $Metadata.Name
                    SuggestedCorrections = $SuggestedCorrections
                }

                Write-Output $DiagnosticRecord
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
