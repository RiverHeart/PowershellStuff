using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects instances of the exclaim operator (`!`).

.DESCRIPTION
    Detects instances of the exclaim operator (`!`).

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls traversal.
    Without this setting, traversal is scope-local.

.EXAMPLE
    Basic usage

    Test-AvoidExclaimOperator -ScriptBlockAst {
        if (! ($x -is [int])) {
            Write-Output "Improper usage detected."
        }
    }.Ast
#>
function Test-AvoidExclaimOperator {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding')]
    param(
        [Parameter(Mandatory, ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory, ParameterSetName='Details')]
        [switch] $Details
    )

    begin {
        $Command = $PSCmdlet.MyInvocation.MyCommand
        $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
        $RuleId = "Nitpick/$RuleName"
        $Metadata = [pscustomobject]@{
            Name = $RuleName
            CommandName = $Command.Name
            Category = 'Style'
            Description = 'Detects instances of the exclaim operator (`!`).'
            Severity = 'Information'
            Explanation = 'Using the `-not` operator is preferred over `!` for readability.'
        }

        # Rule Behavior
        $Behavior = $Context.RuleBehavior

        # ScriptAnalyzer analyzes nested scopes separately; native callers opt into recursion.
        $ShouldRecurse =
            if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
            else { $Behavior.SearchNestedScriptBlocks }
    }

    process {
        if ($Details) { return $Metadata }

        try {
            #-----------------
            # MARK: DETECTION
            #-----------------

            $MatchingExpressions = $ScriptBlockAst.FindAll({
                param($AstNode)

                $AstNode -is [UnaryExpressionAst] -and
                $AstNode.TokenKind -eq 'Exclaim'

            }, $ShouldRecurse)

            $Document = $null
            if ($MatchingExpressions.Count -gt 0) {
                $Document = New-AstDocument -InputObject $ScriptBlockAst
            }

            #-----------------
            # MARK: REPORTING
            #-----------------

            $MatchingExpressions | ForEach-Object {
                $BadNode = $_
                $FilePath = if ($BadNode.Extent.File) { $BadNode.Extent.File } else { '<ScriptBlock>' }
                $Operator = Find-AstToken `
                    -Document $Document `
                    -Kind Exclaim `
                    -Range @($BadNode.Extent.StartOffset, $BadNode.Child.Extent.StartOffset) `
                    -All

                if ($Operator.Count -ne 1) {
                    # nitpick disable-next-line Nitpick/AvoidLongLines
                    throw "Rule '$($Metadata.Name)' could not uniquely locate the exclaim token at offsets [$($BadNode.Extent.StartOffset), $($BadNode.Extent.EndOffset))."
                }

                $BetweenOperatorAndChild = $Document.OriginalText.Substring(
                    $Operator.Extent.EndOffset,
                    $BadNode.Child.Extent.StartOffset - $Operator.Extent.EndOffset
                )

                $Replacement = if ($BetweenOperatorAndChild -match '^\s') {
                    '-not'
                } else {
                    '-not '
                }
                $ChangeReason = "Replace '!' with '-not'."

                New-NitpickFinding `
                    -RuleId $RuleId `
                    -Message "Uses '!' instead of '-not'." `
                    -ViolationExtent $BadNode.Extent `
                    -Severity $Metadata.Severity `
                    -Corrections @(
                        New-NitpickCorrection `
                            -TextEdit (New-AstTextEdit `
                                -Extent $Operator.Extent `
                                -ReplacementText $Replacement `
                                -Reason $ChangeReason) `
                            -FilePathOrContext $FilePath `
                            -Description $ChangeReason `
                            -RuleId $RuleId `
                            -Applicability Safe
                    ) `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation `
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
