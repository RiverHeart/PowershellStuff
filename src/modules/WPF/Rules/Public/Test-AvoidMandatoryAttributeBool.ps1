using namespace System.Management.Automation.Language

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
function Test-AvoidMandatoryAttributeBool {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $FilePath
    )

    process {
        try {
            $FindAstNodeParams = @{
                Type = 'ParameterAst'
                Recurse = $true
                Query = {
                    param($ParameterAst)

                    $MatchingAttribute = Find-WPFAstNode -Ast $ParameterAst -Type 'AttributeAst' -Query {
                        param($AttributeAst)

                        $MandatoryArgument = $AttributeAst.NamedArguments | Where-Object {
                            $_.ArgumentName -eq 'Mandatory' -and -not $_.ExpressionOmitted
                        } | Select-Object -First 1

                        $AttributeAst.TypeName.Name -eq 'Parameter' -and $null -ne $MandatoryArgument
                    }

                    $null -ne $MatchingAttribute
                }
            }

            if ($PSBoundParameters.ContainsKey('FilePath')) {
                $FindAstNodeParams.FilePath = $FilePath
            } elseif ($PSBoundParameters.ContainsKey('ScriptBlockAst')) {
                $FindAstNodeParams.Ast = $ScriptBlockAst
            } else {
                Write-Error 'Either ScriptBlockAst or FilePath is required.'
                return
            }

            Find-WPFAstNode @FindAstNodeParams | ForEach-Object {
                [PSCustomObject]@{
                    Message = "Use '[Parameter(Mandatory)]' or omit the Mandatory argument instead of assigning it a Boolean value."
                    Extent = $_.Extent
                    RuleName = $PSCmdlet.MyInvocation.MyCommand.Name
                    Severity = 'Warning'
                    RuleSuppressionId = 'PSAvoidMandatoryAttributeBool'
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
