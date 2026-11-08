using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects array expressions emitted through an if assignment without array capture.

.DESCRIPTION
    Reports one finding per variable assignment whose if branches emit explicit
    array expressions. Branch output enumerates the arrays, so the assigned value
    may be null, a scalar, or an array depending on the total output. An array type
    constraint on the destination does not turn absent output into an empty array.

    Local assignments, arguments, redirected output, return statements, unary-comma
    protection, and outer array capture are outside this rule's detection scope.
    No dataflow or output-cardinality proof is attempted. Findings are diagnostic-only:
    collection substitution, wrapping, and null filtering require author intent.

.PARAMETER Context
    RuleBehavior.SearchNestedScriptBlocks controls traversal; OutputType selects
    NitpickFinding or DiagnosticRecord. Defaults are scope-local diagnostics.

.EXAMPLE
    Test-ArrayShapeLostThroughControlFlow -ScriptBlockAst {
        $Items = if ($Condition) { @(42) } else { @() }
    }.Ast
#>
function Test-ArrayShapeLostThroughControlFlow {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'DiagnosticRecord', 'PSCustomObject')]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    $Command = $PSCmdlet.MyInvocation.MyCommand
    $RuleName = $Command.Noun
    $RuleId = "Nitpick/$RuleName"
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Correctness'
        Description = 'Detects explicit array output losing its shape through an if assignment.'
        Severity = 'Warning'
        Explanation = 'Branch output enumerates arrays. Initialize the destination collection separately and add emitted items to it when its shape must remain stable. Preserve explicit null items unless filtering them is intentional.'
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $Assignments = $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [AssignmentStatementAst] -and
            $Node.Operator -eq [TokenKind]::Equals -and
            $Node.Right -is [IfStatementAst]
    }, $ShouldRecurse)

    foreach ($Assignment in $Assignments) {
        $Destination = $Assignment.Left
        while ($Destination -is [ConvertExpressionAst]) {
            $Destination = $Destination.Child
        }
        if ($Destination -isnot [VariableExpressionAst] -or
            $Destination.VariablePath.UserPath -eq 'null'
        ) {
            continue
        }

        $HasArrayOutput = $false
        $HasEmptyArrayOutput = $false
        $Arrays = $Assignment.Right.FindAll({
            param($Node)
            $Node -is [ArrayExpressionAst] -or $Node -is [ArrayLiteralAst]
        }, $false)

        foreach ($Array in $Arrays) {
            # Unary comma is itself an ArrayLiteralAst; its operand is protected.
            if ($Array -is [ArrayLiteralAst] -and $Array.Elements.Count -eq 1) { continue }

            $Current = $Array
            while ($Current -ne $Assignment.Right) {
                $Parent = $Current.Parent
                $IsTransparent = switch ($Parent) {
                    { $_ -is [CommandExpressionAst] } {
                        $_.Expression -eq $Current -and $_.Redirections.Count -eq 0
                        break
                    }
                    { $_ -is [PipelineAst] } {
                        $_.PipelineElements.Count -eq 1 -and
                            $_.PipelineElements[0] -eq $Current -and
                            -not ($_.PSObject.Properties['Background'] -and $_.Background)
                        break
                    }
                    { $_ -is [ParenExpressionAst] } { $true; break }
                    { $_ -is [StatementBlockAst] } {
                        $_.Parent -is [IfStatementAst] -and $_.Statements.Contains($Current)
                        break
                    }
                    { $_ -is [IfStatementAst] } {
                        $Current -is [StatementBlockAst]
                        break
                    }
                    default { $false }
                }

                if (-not $IsTransparent) { break }
                $Current = $Parent
            }

            if ($Current -ne $Assignment.Right) { continue }
            $HasArrayOutput = $true
            if ($Array -is [ArrayExpressionAst] -and
                $Array.SubExpression.Statements.Count -eq 0
            ) {
                $HasEmptyArrayOutput = $true
            }
        }

        if (-not $HasArrayOutput) { continue }

        $Message = 'Arrays emitted by this if are enumerated before assignment; the result may be null, a scalar, or an array rather than retaining the emitted array shape.'
        if ($HasEmptyArrayOutput) {
            $Message += ' An empty @() emits no items, not an empty array object; typing the destination as [array] does not fix absent output.'
        }
        $Message += ' Initialize the destination collection separately and add the emitted items when stable collection shape is intended.'
        $FilePath = if ($Assignment.Extent.File) { $Assignment.Extent.File } else { '<ScriptBlock>' }

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message $Message `
            -ViolationExtent $Assignment.Right.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation `
            -OutputAs $OutputAs
    }
}
