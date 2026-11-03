using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    PSScriptAnalyzer rule to detect instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.

.DESCRIPTION
    PSScriptAnalyzer rule to detect instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.

    The rule suggests using the `[Parameter(<Attribute>)]` when the parameter is required,
    and omitting the attribute when the parameter is optional.
    Standalone native findings and corrections use Nitpick/AvoidParameterAttributeBool.
    Coordinated execution replaces that identity with the executing descriptor's ID.

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls traversal
    and RuleBehavior.OutputType selects NitpickFinding or DiagnosticRecord output.
    Without these settings, traversal is scope-local and output is DiagnosticRecord.

.EXAMPLE
    Test-AvoidParameterAttributeBool -ScriptBlockAst {
        param(
            [Parameter(Mandatory=$true)]
            [string] $Foo
        )
    }.Ast
#>
function Test-AvoidParameterAttributeBool {
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
        $AttributeList = @(
            'Mandatory'
            'ValueFromPipeline'
            'ValueFromPipelineByPropertyName'
            'ValueFromRemainingArguments'
            'DontShow'
        )
        $Command = $PSCmdlet.MyInvocation.MyCommand
        $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
        $RuleId = "Nitpick/$RuleName"
        $Metadata = [pscustomobject]@{
            Name = $RuleName
            CommandName = $Command.Name
            Category = 'Style'
            Description = 'Detects instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.'
            Severity = 'Information'
            Explanation = 'Assigning Boolean values to Parameter attribute arguments is unnecessary and makes them harder to read.'
        }
        $Behavior = $Context.RuleBehavior
        $ShouldRecurse = if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false } else { $Behavior.SearchNestedScriptBlocks }
        $OutputAs = if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' } else { $Behavior.OutputType }
    }

    process {
        if ($Details) { return $Metadata }

        try {
            $ParameterAttributes = $ScriptBlockAst.FindAll({
                param($Ast)

                $Ast -is [AttributeAst] -and
                $Ast.TypeName.Name -eq 'Parameter' -and
                $Ast.Parent -is [ParameterAst]
            }, $ShouldRecurse <# ScriptAnalyzer analyzes nested scopes separately; native callers opt into recursion. #>)

            $MatchingArguments = foreach ($AttributeAst in $ParameterAttributes) {
                $AttributeAst.NamedArguments | Where-Object {
                    -not $_.ExpressionOmitted -and
                    $_.ArgumentName -in $AttributeList -and
                    $_.Argument.Extent.Text -in '$true', '$false'
                }
            }

            $MatchingArguments | ForEach-Object {
                $BadNode = $_
                $ArgumentName = $BadNode.ArgumentName
                $CorrectionParams = @{}

                # The correction depends on what the boolean value is set to
                # False: argument should be omitted
                # True: argument should have no explicit value
                if ($BadNode.Argument.Extent.Text -eq '$true') {
                    $Description = "Use '[Parameter($ArgumentName)]' instead of assigning it `$true`."

                    # NOTE: This is a lot but was required to produce the correct extent
                    # for carets in the ast diff.
                    $StartOffset = $BadNode.Extent.StartOffset + $ArgumentName.Length
                    $EndOffset = $BadNode.Argument.Extent.EndOffset

                    $CorrectionParams.TextEdit = New-AstTextEdit `
                        -StartLineNumber $BadNode.Extent.StartLineNumber `
                        -EndLineNumber $BadNode.Argument.Extent.EndLineNumber `
                        -StartColumnNumber ($BadNode.Extent.StartColumnNumber + $ArgumentName.Length) `
                        -EndColumnNumber $BadNode.Argument.Extent.EndColumnNumber `
                        -StartOffset $StartOffset `
                        -EndOffset $EndOffset `
                        -ExpectedText $BadNode.Extent.Text.Substring($ArgumentName.Length) `
                        -ReplacementText '' `
                        -Reason $Description

                } elseif ($BadNode.Argument.Extent.Text -eq '$false') {
                    $Description = "Omit the '$ArgumentName' argument instead of assigning it `$false`."
                    $CorrectionParams.TextEdit = New-AstCollectionEdit `
                        -Remove $BadNode `
                        -From $BadNode.Parent.NamedArguments `
                        -Within $BadNode.Parent
                } else {
                    return  # Something went wrong, not a boolean literal
                }

                $FilePath = if ($BadNode.Extent.FileName) {
                    $BadNode.Extent.FileName
                } else {
                    '<ScriptBlock>'
                }

                $CorrectionParams.FilePathOrContext = $FilePath
                $CorrectionParams.Description = $Description
                $CorrectionParams.RuleId = $RuleId
                $Correction = New-NitpickCorrection @CorrectionParams

                $Finding = New-NitpickFinding `
                    -RuleId $RuleId `
                    -Message "Avoid assigning Boolean values to Parameter attribute arguments" `
                    -ViolationExtent $BadNode.Extent `
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
