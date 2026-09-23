using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Nitpick rule.

.EXAMPLE
    Basic usage

    Test-AvoidBlockingUI -ScriptBlockAst {
        Start-Sleep -Seconds 1
    }.Ast
#>
function Test-AvoidBlockingUI {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst
    )

    begin {
        $KnownBlockingCommands = @(
            'Start-Sleep'
            'Wait-*'
        )
    }

    process {
        try {
            $MatchingNodes = $ScriptBlockAst.FindAll({
                param($Ast)

                if ($Ast -isnot [System.Management.Automation.Language.CommandAst]) {
                    return $false
                }

                if ($Ast.CommandElements[0].Extent.Text -in $KnownBlockingCommands) {
                    return $true
                }

                # Matching nothing in case this rule is auto-detected by ScriptAnalyzer
                return $false
            }, $false <# Do not enter nested script blocks; ScriptAnalyzer analyzes those scopes separately. #>)

            $MatchingNodes | ForEach-Object {
                $BadNode = $_

                $FilePath = if ($BadNode.Extent.FileName) {
                    $BadNode.Extent.FileName
                } else {
                    Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1 -ExpandProperty ScriptName
                }
                if (-not $FilePath) { $FilePath = '<ScriptBlock>' }

                $DiagnosticRecord = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    Message = "Synchronous blocking detected in UI handler."
                    Extent = $BadNode.Extent
                    RuleName = $PSCmdlet.MyInvocation.MyCommand.Name
                    Severity = 'Information'
                    RuleSuppressionID = 'AvoidBlockingUI'
                    ScriptPath = $FilePath
                }

                Write-Output $DiagnosticRecord
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
