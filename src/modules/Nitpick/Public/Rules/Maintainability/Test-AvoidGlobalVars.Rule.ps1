using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects variables declared in the global scope.

.DESCRIPTION
    Reports reads and writes that explicitly use the global variable scope.
    Intentional global state is valid, but process-wide mutable state makes
    behavior harder to reason about, isolate, and safely change. Findings are
    diagnostic-only; use a narrower scope or explicitly suppress intentional
    process-wide state.

.PARAMETER Context
    RuleBehavior.SearchNestedScriptBlocks controls traversal. The default is
    scope-local.

.EXAMPLE
    Test-AvoidGlobalVars -ScriptBlockAst {
        $global:LastResult = 'complete'
    }.Ast
#>
function Test-AvoidGlobalVars {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'PSCustomObject')]
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
        Category = 'Maintainability'
        Description = 'Detects variables declared in the global scope.'
        Severity = 'Warning'
        Explanation = (
            'Global variables make behavior depend on process-wide mutable state,' +
            ' making code harder to reason about, isolate, and change. Prefer a local,' +
            ' script, or caller-owned value when possible.'
        )
    }

    if ($Details) {
        Write-Output $Metadata
        return
    }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }

    $GlobalVariables = $ScriptBlockAst.FindAll({
        param($Node)

        $Node -is [VariableExpressionAst] -and
            $Node.VariablePath.IsGlobal
    }, $ShouldRecurse)

    foreach ($Variable in $GlobalVariables) {
        $FilePath = if ($Variable.Extent.File) {
            $Variable.Extent.File
        } else {
            '<ScriptBlock>'
        }

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message "Avoid using global variable '$($Variable.VariablePath.UserPath)'." `
            -ViolationExtent $Variable.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation
    }
}
