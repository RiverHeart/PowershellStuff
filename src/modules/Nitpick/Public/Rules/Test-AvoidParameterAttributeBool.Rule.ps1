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
        $Metadata = [pscustomobject]@{
            Name = 'AvoidParameterAttributeBool'
            CommandName = $PSCmdlet.MyInvocation.MyCommand.Name
            Category = 'Style'
            Description = 'Detects instances of the `[Parameter(<Attribute>=<Bool>)]` pattern.'
            Severity = 'Information'
            Explanation = 'Assigning Boolean values to Parameter attribute arguments is unnecessary and makes them harder to read.'
        }
    }

    process {
        if ($Details) { return $Metadata }

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
            }, $false <# Do not enter nested script blocks; ScriptAnalyzer analyzes those scopes separately. #>)

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

                $Correction = New-NitpickCorrection `
                    -StartLineNumber $BadNode.Extent.StartLineNumber `
                    -EndLineNumber $BadNode.Extent.EndLineNumber `
                    -StartColumnNumber $BadNode.Extent.StartColumnNumber `
                    -EndColumnNumber $BadNodeEndColumnNumber `
                    -ReplacementText $ReplacementText `
                    -FilePathOrContext $FilePath `
                    -Description $Description

                $OutputAs = if (Test-AssemblyLoaded -Name 'Microsoft.Windows.PowerShell.ScriptAnalyzer') {
                    'DiagnosticRecord'
                } else {
                    'NitpickFinding'
                }
                $Finding = New-NitpickFinding `
                    -RuleName $PSCmdlet.MyInvocation.MyCommand.Name `
                    -Message "Avoid assigning Boolean values to Parameter attribute arguments" `
                    -ViolationExtent $BadNode.Extent `
                    -Severity $Metadata.Severity `
                    -RuleSuppressionID $Metadata.Name `
                    -Corrections $Correction `
                    -OutputAs $OutputAs `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation `

                Write-Output $Finding
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
