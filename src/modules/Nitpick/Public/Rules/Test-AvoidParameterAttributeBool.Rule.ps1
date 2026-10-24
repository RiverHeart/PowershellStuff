<#
.SYNOPSIS
    PSScriptAnalyzer rule to detect instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.

.DESCRIPTION
    PSScriptAnalyzer rule to detect instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.

    The rule suggests using the `[Parameter(<Attribute>)]` when the parameter is required,
    and omitting the attribute when the parameter is optional.

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
        [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,

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
        $Metadata = [pscustomobject]@{
            Name = $RuleName
            CommandName = $Command.Name
            Category = 'Style'
            Description = 'Detects instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.'
            Severity = 'Information'
            Explanation = 'Assigning Boolean values to Parameter attribute arguments is unnecessary and makes them harder to read.'
        }
    }

    process {
        if ($Details) { return $Metadata }

        try {
            $ParameterAttributes = $ScriptBlockAst.FindAll({
                param($Ast)

                $Ast -is [System.Management.Automation.Language.AttributeAst] -and
                    $Ast.TypeName.Name -eq 'Parameter' -and
                    $Ast.Parent -is [System.Management.Automation.Language.ParameterAst]
            }, $false <# Do not enter nested script blocks; ScriptAnalyzer analyzes those scopes separately. #>)

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
                    $CorrectionParams.ViolationExtent = $BadNode.Extent
                    $CorrectionParams.ReplacementText = $ArgumentName
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
                $CorrectionParams.RuleName = $RuleName
                $Correction = New-NitpickCorrection @CorrectionParams

                $Finding = New-NitpickFinding `
                    -RuleName $RuleName `
                    -Message "Avoid assigning Boolean values to Parameter attribute arguments" `
                    -ViolationExtent $BadNode.Extent `
                    -Severity $Metadata.Severity `
                    -RuleSuppressionID $RuleName `
                    -Corrections $Correction `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation `

                Write-Output $Finding
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
