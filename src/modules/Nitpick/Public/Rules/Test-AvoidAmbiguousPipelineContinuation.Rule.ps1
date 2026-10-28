using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects separate commands formatted as continuations of a preceding pipeline.

.DESCRIPTION
    Reports an adjacent command aligned with the last command of a multiline
    pipeline, including pipelines on the right-hand side of assignments.
    The continuation must be indented beyond the preceding statement and both
    commands must start after whitespace only. Blank lines, comments, and explicit
    statement separators make the separation unambiguous.

    Findings are diagnostic-only: adding a pipe or separating statements requires
    the author's intent, which cannot be inferred from formatting.

.NOTES
    Warns when a separate command on the next physical line is aligned with
    the final, indented command of a multiline pipeline. It also checks
    pipelines assigned to variables.

    ```powershell
    Get-ChildItem |
        Where-Object { $_.Name }
        ForEach-Object { $_.FullName }  # Separate statement, despite the alignment
    ```

    Add the missing `|` if continuation was intended. Otherwise, insert a blank
    line or dedent the independent command. The rule does not infer command behavior
    from names, parameters, or `$_`, and offers no automatic corrections.

    Detection requires matching whitespace indentation (tabs and spaces are not
    interchangeable), sibling statements in the same statement list, and a pipeline
    starting with a command. Blank lines, intervening comments, explicit semicolons,
    and single-line pipelines are not reported. This is a formatting heuristic, not
    proof of an execution bug.

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls traversal
    and RuleBehavior.OutputType selects NitpickFinding or DiagnosticRecord output.
    Without these settings, traversal is scope-local and output is DiagnosticRecord.

.EXAMPLE
    Test-AvoidAmbiguousPipelineContinuation -ScriptBlockAst {
        Get-ChildItem |
            Where-Object { $_.Name }
            ForEach-Object { $_.FullName }
    }.Ast
#>
function Test-AvoidAmbiguousPipelineContinuation {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord', 'PSCustomObject')]
    param(
        [Parameter(Mandatory, ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [System.Collections.IDictionary] $Context,

        [Parameter(ParameterSetName='Details')]
        [switch] $Details
    )

    $Command = $PSCmdlet.MyInvocation.MyCommand
    $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Style'
        Description = 'Detects ambiguous pipeline continuation formatting between separate statements.'
        Severity = 'Warning'
        Explanation = 'Adjacent commands aligned with an indented pipeline continuation can conceal a missing pipe or an intended statement boundary.'
    }
    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse = if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false } else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs = if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' } else { $Behavior.OutputType }

    $Pipelines = $ScriptBlockAst.FindAll({
        param($Node)

        $Node -is [PipelineAst] -and
            $Node.PipelineElements.Count -gt 1 -and
            $Node.PipelineElements[0] -is [CommandAst]
    }, $ShouldRecurse)

    $Source = $ScriptBlockAst.Extent.StartScriptPosition.GetFullScript()
    foreach ($Pipeline in $Pipelines) {
        $Statement = $Pipeline
        if ($Pipeline.Parent -is [AssignmentStatementAst] -and $Pipeline.Parent.Right -eq $Pipeline) {
            $Statement = $Pipeline.Parent
        }
        $Container = $Statement.Parent
        if ($Container -isnot [StatementBlockAst] -and $Container -isnot [NamedBlockAst]) {
            continue
        }

        $Statements = $Container.Statements
        $Index = $Statements.IndexOf($Statement)
        if ($Index -lt 0 -or $Index + 1 -ge $Statements.Count) { continue }
        $Next = $Statements[$Index + 1]
        if ($Next -isnot [PipelineAst] -or $Next.PipelineElements[0] -isnot [CommandAst]) {
            continue
        }

        $LastCommand = $Pipeline.PipelineElements[-1]
        if ($LastCommand -isnot [CommandAst] -or
            $LastCommand.Extent.StartLineNumber -le $Pipeline.Extent.StartLineNumber -or
            $LastCommand.Extent.StartColumnNumber -le $Statement.Extent.StartColumnNumber -or
            $Next.Extent.StartLineNumber -ne $Statement.Extent.EndLineNumber + 1) {
            continue
        }

        $Indent = $LastCommand.Extent.StartScriptPosition.Line.Substring(0, $LastCommand.Extent.StartColumnNumber - 1)
        $NextIndent = $Next.Extent.StartScriptPosition.Line.Substring(0, $Next.Extent.StartColumnNumber - 1)
        if ($Indent -notmatch '\A[ \t]+\z' -or $Indent -cne $NextIndent) { continue }

        $Gap = $Source.Substring($Statement.Extent.EndOffset, $Next.Extent.StartOffset - $Statement.Extent.EndOffset)
        if ($Gap -notmatch '\A[ \t]*\r?\n[ \t]*\z') { continue }

        $NextCommand = $Next.PipelineElements[0]
        $CommandText = $NextCommand.CommandElements[0].Extent.Text
        $FilePath = if ($Next.Extent.File) { $Next.Extent.File } else { '<ScriptBlock>' }
        New-NitpickFinding `
            -RuleName $RuleName `
            -Message "Ambiguous pipeline continuation: '$CommandText' is aligned with the preceding pipeline but starts a separate statement. Add '|' to continue the pipeline, or insert a blank line or dedent the command to make the separation explicit." `
            -ViolationExtent $NextCommand.CommandElements[0].Extent `
            -Severity $Metadata.Severity `
            -RuleSuppressionID $RuleName `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation `
            -OutputAs $OutputAs
    }
}
