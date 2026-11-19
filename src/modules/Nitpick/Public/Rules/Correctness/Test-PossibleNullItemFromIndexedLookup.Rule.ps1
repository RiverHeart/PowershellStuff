using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Highlights direct indexed lookups captured as arrays that may contain a null item.

.DESCRIPTION
    Reports @(indexed lookup), including parenthesized lookups, without inferring
    the indexed object's type or proving that a key is missing. A lookup returning
    an explicit null produces one null array item, not an empty array.

    Pipelines, guards, multiple statements, redirections, and other transformed
    expressions are excluded. Casts on the containing expression or destination
    do not express a null-handling policy and do not suppress the finding.
    Findings are diagnostic-only. Use native suppression for intentional capture.

.PARAMETER Context
    RuleBehavior.SearchNestedScriptBlocks controls traversal; OutputType selects
    NitpickFinding or DiagnosticRecord. Defaults are scope-local diagnostics.

.EXAMPLE
    Test-PossibleNullItemFromIndexedLookup -ScriptBlockAst {
        $Items = @($Map['Key'])
    }.Ast
#>
function Test-PossibleNullItemFromIndexedLookup {
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
        Description = 'Highlights possible null items from direct indexed lookups captured as arrays.'
        Severity = 'Information'
        Explanation = 'An indexed lookup returning explicit null contributes one null item to array capture. Missing-key handling and explicit-null filtering are different policies; neither is inferred or automatically applied.'
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $Arrays = $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [ArrayExpressionAst]
    }, $ShouldRecurse)

    foreach ($Array in $Arrays) {
        if ($Array.SubExpression.Statements.Count -ne 1 -or
            $Array.SubExpression.Traps.Count -gt 0
        ) {
            continue
        }

        $Current = $Array.SubExpression.Statements[0]
        while ($Current -is [PipelineAst]) {
            if ($Current.PipelineElements.Count -ne 1 -or
                ($Current.PSObject.Properties['Background'] -and $Current.Background)
            ) {
                break
            }

            $Element = $Current.PipelineElements[0]
            if ($Element -isnot [CommandExpressionAst] -or $Element.Redirections.Count -gt 0) {
                break
            }

            $Current = $Element.Expression
            if ($Current -is [ParenExpressionAst]) {
                $Current = $Current.Pipeline
            }
        }

        if ($Current -isnot [IndexExpressionAst]) { continue }

        $FilePath = if ($Array.Extent.File) { $Array.Extent.File } else { '<ScriptBlock>' }
        New-NitpickFinding `
            -RuleId $RuleId `
            -Message 'If this indexed lookup returns $null, @(...) captures one null item, not an empty array. For hashtable keys, use a ContainsKey() guard when missing keys should emit nothing; filter explicit nulls only when intended, or suppress this finding for intentional capture.' `
            -ViolationExtent $Array.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation `
            -OutputAs $OutputAs
    }
}
