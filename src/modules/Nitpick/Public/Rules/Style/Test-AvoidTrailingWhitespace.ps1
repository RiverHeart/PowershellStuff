using namespace System.Collections
using namespace System.Management.Automation.Language
using module AstEditor

<#
.SYNOPSIS
    PSScriptAnalyzer adapter for the native trailing-whitespace rule.

.DESCRIPTION
    Converts the ScriptBlockAst supplied by PSScriptAnalyzer to an AstDocument
    and delegates to Measure-AvoidTrailingWhitespace.

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

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    if ($Details) {
        return Measure-AvoidTrailingWhitespace -Details
    }

    $Document = New-AstDocument -InputObject $ScriptBlockAst
    Measure-AvoidTrailingWhitespace -InputObject $Document -Context $Context
}

<#
.SYNOPSIS
    Finds and corrects trailing whitespace in an AstDocument.

.DESCRIPTION
    Preserves whitespace in multiline strings and here-strings as well as
    backtick-escaped spaces. Candidates overlapping meaningful tokens are ignored.
    Parse errors prevent automatic corrections, but unprotected candidates still
    produce findings.

.PARAMETER Document
    The complete source snapshot and parsed metadata to analyze.

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls traversal
    and RuleBehavior.OutputType selects NitpickFinding or DiagnosticRecord output.
    Without these settings, traversal is scope-local and output is DiagnosticRecord.

.EXAMPLE
    $Document = New-AstDocument -InputObject '$Value = 1  '
    Measure-AvoidTrailingWhitespace -Document $Document
#>
function Measure-AvoidTrailingWhitespace {
    [CmdletBinding(DefaultParameterSetName='Document')]
    [OutputType([object[]], [hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='Document',ValueFromPipeline)]
        [AstDocument] $InputObject,

        [Parameter(ParameterSetName='Document')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
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

        $Document = $InputObject

        try {
            $ShouldRecurse = $Behavior.SearchNestedScriptBlocks -eq $true
            $NestedScopes = if (-not $ShouldRecurse) {
                $Document.Ast.FindAll({
                    param($Node)

                    $Node -is [ScriptBlockAst] -and
                    -not [object]::ReferenceEquals($Node, $Document.Ast)
                }, $true) -as [array]
            } else { @() }

            [array] $ProtectedTokens = $Document.Root.Tokens | Where-Object {
                $_.Kind -notin 'Comment', 'NewLine', 'LineContinuation', 'EndOfInput'
            }

            $FilePath =
                if ($Document.Ast.Extent.File) { $Document.Ast.Extent.File }
                else { '<ScriptBlock>' }

            foreach ($Extent in (
                AstEditor\Find-AstScriptExtent `
                    -Document $Document `
                    -Pattern $CandidatePattern
            )) {
                # A fragment's end may be in the middle of a physical source line.
                if ($Extent.EndOffset -lt $Document.OriginalText.Length -and
                    $Document.OriginalText[$Extent.EndOffset] -notin [char] 13, [char] 10
                ) {
                    continue
                }

                $IsProtected = $false
                foreach ($Token in $ProtectedTokens) {
                    if ($Token.Extent.StartOffset -lt $Extent.EndOffset -and
                        $Extent.StartOffset -lt $Token.Extent.EndOffset
                    ) {
                        $IsProtected = $true
                        break
                    }
                }

                foreach ($Scope in $NestedScopes) {
                    if ($Scope.Extent.StartOffset -lt $Extent.EndOffset -and
                        $Extent.StartOffset -lt $Scope.Extent.EndOffset
                    ) {
                        $IsProtected = $true
                        break
                    }
                }

                if ($IsProtected) { continue }

                $Corrections = @()
                if ($Document.Root.ParseErrors.Count -eq 0) {
                    $Edit = New-AstTextEdit -Extent $Extent -ReplacementText '' -Reason 'Remove trailing whitespace.'
                    $Corrections = @(
                        New-NitpickCorrection `
                            -TextEdit $Edit `
                            -FilePathOrContext $FilePath `
                            -Description 'Remove trailing whitespace.' `
                            -RuleId $RuleId `
                            -Applicability Safe
                    )
                }
                New-NitpickFinding `
                    -RuleId $RuleId `
                    -Message "Avoid trailing whitespace" `
                    -ViolationExtent $Extent `
                    -Severity $Metadata.Severity `
                    -Corrections $Corrections `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation `
                    -OutputAs $OutputAs
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
