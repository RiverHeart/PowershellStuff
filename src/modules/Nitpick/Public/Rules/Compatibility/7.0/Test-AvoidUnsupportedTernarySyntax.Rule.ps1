using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects ternary expressions when a project requires earlier PowerShell syntax.

.DESCRIPTION
    Ternary expressions were introduced in PowerShell 7.0. Descriptor invocation
    runs this detection-only rule when the configured minimum syntax version is
    below 7.0 and requires a PowerShell 7.0 or later analysis host.

    Standalone producer calls bypass descriptor applicability and host checks.
    No automatic corrections are offered.

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls
    traversal and RuleBehavior.OutputType selects NitpickFinding or
    DiagnosticRecord output. Standalone defaults are scope-local traversal and
    DiagnosticRecord output.

.EXAMPLE
    Test-AvoidUnsupportedTernarySyntax -Details
#>
function Test-AvoidUnsupportedTernarySyntax {
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
    $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
    $RuleId = "Nitpick/$RuleName"
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Compatibility'
        Description = 'Detects ternary syntax unsupported by the configured minimum PowerShell version.'
        Severity = 'Warning'
        Explanation = 'Ternary expressions require PowerShell 7.0 or later.'
        Applicability = {
            param([IDictionary] $Context)
            $Minimum = $Context.Policy.Compatibility.PowerShell.MinimumVersion
            $null -ne $Minimum -and $Minimum -lt [version] '7.0'
        }
        MinimumAnalysisHostVersion = [version] '7.0'
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $Candidates = $ScriptBlockAst.FindAll({
        param($Node)

        $Node.GetType().FullName -eq 'System.Management.Automation.Language.TernaryExpressionAst'
    }, $ShouldRecurse)

    foreach ($Candidate in $Candidates) {
        $FilePath = if ($Candidate.Extent.File) {
            $Candidate.Extent.File
        } else {
            '<ScriptBlock>'
        }

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message 'Ternary syntax requires PowerShell 7.0 or later.' `
            -ViolationExtent $Candidate.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation `
            -OutputAs $OutputAs
    }
}
