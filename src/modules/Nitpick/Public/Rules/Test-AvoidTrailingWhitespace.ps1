using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    PSScriptAnalyzer rule to detect instances of trailing whitespace.

.DESCRIPTION
    PSScriptAnalyzer rule to detect instances of trailing whitespace.

    Preserves whitespace in multiline strings and here-strings as well
    as backtick escaped spaces.

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls traversal
    and RuleBehavior.OutputType selects NitpickFinding or DiagnosticRecord output.
    Without these settings, traversal is scope-local and output is DiagnosticRecord.

.EXAMPLE
    Test-AvoidTrailingWhitespace -ScriptBlockAst {
        param(
            [string] $Foo
        )
    }.Ast
#>
function Test-AvoidTrailingWhitespace {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([object[]], [hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(ParameterSetName='Details')]
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
            Description = 'Detects instances of trailing whitespace.'
            Severity = 'Information'
            Explanation = 'Trailing whitespace is unnecessary and should be removed.'
        }
        $Behavior = $Context.RuleBehavior
        $OutputAs = if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' } else { $Behavior.OutputType }

        # Pattern to match trailing whitespace at the end of lines
        # while preserving line endings and a final unterminated line.
        $CandidatePattern = '[ \t]+(?=\r\n|\n|\r|\z)'
    }

    process {
        if ($Details) { return $Metadata }

        try {
            Find-AstScriptExtent `
                -Document $Document `
                -Pattern $CandidatePattern `
                -Multiline |
            ForEach-Object {
                $Extent = $_

                $CorrectionParams = @{}
                $CorrectionParams.TextEdit = New-AstTextEdit `
                    -Extent $Extent `
                    -ReplacementText '' `
                    -Reason 'Remove trailing whitespace.'

                $FilePath = if ($ScriptBlockAst.Extent.FileName) {
                    $ScriptBlockAst.Extent.FileName
                } else {
                    '<ScriptBlock>'
                }

                $CorrectionParams.FilePathOrContext = $FilePath
                $CorrectionParams.Description = 'Remove trailing whitespace.'
                $CorrectionParams.RuleId = $RuleId
                $Correction = New-NitpickCorrection @CorrectionParams

                $Finding = New-NitpickFinding `
                    -RuleId $RuleId `
                    -Message "Avoid trailing whitespace" `
                    -ViolationExtent $ScriptBlockAst.Extent `
                    -Severity $Metadata.Severity `
                    -Corrections $Correction `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation `
                    -OutputAs $OutputAs

                Write-Output $Finding
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
