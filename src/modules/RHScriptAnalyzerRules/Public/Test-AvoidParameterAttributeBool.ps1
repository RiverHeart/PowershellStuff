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
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst
    )

    begin {
        $AttributeList = @(
            'Mandatory'
            'ValueFromPipeline'
            'ValueFromPipelineByPropertyName'
            'ValueFromRemainingArguments'
            'DontShow'
        )
    }

    process {
        try {
            $MatchingParameters = $ScriptBlockAst.FindAll({
                param($Ast)

                # Specifically, we're interested in [Parameter(...)] attributes
                if ($Ast -isnot [System.Management.Automation.Language.NamedAttributeArgumentAst]) {
                    return $false
                }

                if ($Ast.ExpressionOmitted) {
                    return $false
                }

                if ($Ast.ArgumentName -notin $AttributeList) {
                    return $false
                }

                if ($Ast.Argument.Extent.Text -notin '$true', '$false') {
                    return $false
                }

                # Now that we've verified that we have expressionless NamedArgumentAst,
                # we need to walk up the AST to check if it belongs to a [Parameter(...)] attribute
                $AttributeAst = $Ast.Parent
                if ($AttributeAst -isnot [System.Management.Automation.Language.AttributeAst] -or
                    $AttributeAst.TypeName.Name -ne 'Parameter'
                ) {
                    return $false
                }

                $ParameterAst = $AttributeAst.Parent
                if ($ParameterAst -isnot [System.Management.Automation.Language.ParameterAst]) {
                    return $false
                }

                return $true
            }, $false <# DO NOT RECURSE, you will get duplicate matches from Invoke-ScriptAnalyzer #>)

            $MatchingParameters | ForEach-Object {
                $BadNode = $_
                $ArgumentName = $BadNode.ArgumentName
                $BadNodeIndex = $BadNode.Parent.NamedArguments.IndexOf($BadNode)
                $HasTrailingComma = $null -ne $BadNode.Parent.NamedArguments[$BadNodeIndex + 1]
                $BadNodeEndColumnNumber = $BadNode.Extent.EndColumnNumber

                # The correction depends on what the boolean value is set to
                # False: argument should be omitted
                # True: argument should have no explicit value
                if ($BadNode.Argument.Extent.Text -eq '$true') {
                    $ReplacementText = $ArgumentName
                    $Description = "Use '[Parameter($ArgumentName)]' instead of assigning it `$true`."
                } elseif ($BadNode.Argument.Extent.Text -eq '$false') {
                    # This is naive, assumes that the next token is a comma but could be
                    # malformed. Probably good enough 99% of the time.
                    if ($HasTrailingComma) {
                        $BadNodeEndColumnNumber += 1
                    }
                    $ReplacementText = ''
                    $Description = "Omit the '$ArgumentName' argument instead of assigning it `$false`."
                } else {
                    return  # Something went wrong, not a boolean literal
                }

                $FilePath = if ($BadNode.Extent.FileName) {
                    $BadNode.Extent.FileName
                } else {
                    Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1 -ExpandProperty ScriptName
                }
                if (-not $FilePath) { $FilePath = '<ScriptBlock>' }

                $CorrectionExtent = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::new(
                    $BadNode.Extent.StartLineNumber,
                    $BadNode.Extent.EndLineNumber,
                    $BadNode.Extent.StartColumnNumber,
                    $BadNodeEndColumnNumber,
                    $ReplacementText,
                    $FilePath,  # File Path or Context
                    $Description  # Hover Text Description
                )
                $SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]]::new()
                $SuggestedCorrections.Add($CorrectionExtent)

                $DiagnosticRecord = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    Message = "Avoid assigning Boolean values to Parameter attribute arguments"
                    Extent = $BadNode.Extent
                    RuleName = $PSCmdlet.MyInvocation.MyCommand.Name
                    Severity = 'Warning'
                    RuleSuppressionID = 'PSAvoidParameterAttributeBool'
                    SuggestedCorrections = $SuggestedCorrections
                }

                Write-Output $DiagnosticRecord
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
