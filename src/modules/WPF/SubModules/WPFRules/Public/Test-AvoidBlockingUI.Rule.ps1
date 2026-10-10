using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Nitpick rule.

.EXAMPLE
    Basic usage

    Test-AvoidBlockingUI -ScriptBlockAst {
        Window {
            On Loaded {
                Start-Sleep -Seconds 1
            }

            $this.Add_Loaded({
                Start-Sleep -Seconds 1
            })

            Button {
                On Click {
                    Start-Sleep -Seconds 1
                    if ($ReallyTired) {
                        Wait-Longer
                    }
                }
            }
        }
    }.Ast
#>
function Test-AvoidBlockingUI {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    begin {
        $Metadata = [pscustomobject]@{
            Name = 'AvoidBlockingUI'
            Command = $PSCmdlet.MyInvocation.MyCommand.Name
            Category = 'Performance'
            Description = 'Detects usage of blocking commands (e.g., Start-Sleep, Wait-*) within UI event handlers.'
            Severity = 'Warning'
            Explanation = 'Blocking commands within UI event handlers can cause the UI to become unresponsive.'
        }
    }

    process {
        if ($Details) { return $Metadata }

        $KnownBlockingCommands = @(
            'Start-Sleep'
            'Wait-*'
        )

        try {
            $HandlerScriptBlocks = @()

            # Check if the the given script block is part of an event handler
            # itself (e.g., On Loaded, Add_Click)
            $ParentExpressionAst = $ScriptBlockAst.Parent
            if ($ParentExpressionAst -is [ScriptBlockExpressionAst] -and
                ((
                    $ParentExpressionAst.Parent -is [CommandAst] -and
                    $ParentExpressionAst.Parent.GetCommandName() -in @('On', 'Key')
                ) -or (
                    $ParentExpressionAst.Parent -is [InvokeMemberExpressionAst] -and
                    $ParentExpressionAst.Parent.Member.Value -like 'Add_*'
                ))
            ) {
                $HandlerScriptBlocks += $ScriptBlockAst
            }

            # Then, find all handler commands (e.g., On Loaded, Key events) within the script block
            $HandlerCommands = $ScriptBlockAst.FindAll({
                param($Ast)

                return $Ast -is [CommandAst] -and $Ast.GetCommandName() -in @('On', 'Key')
            }, $true)

            foreach ($HandlerCommand in $HandlerCommands) {
                $HandlerExpressionAst = $HandlerCommand.CommandElements |
                    Where-Object { $_ -is [ScriptBlockExpressionAst] } |
                    Select-Object -First 1

                if ($HandlerExpressionAst) {
                    $HandlerScriptBlocks += $HandlerExpressionAst.ScriptBlock
                }
            }

            # Find all event registration expressions (e.g., Add_Click) within the script block
            $EventRegistrationExpressions = $ScriptBlockAst.FindAll({
                param($Ast)

                return $Ast -is [InvokeMemberExpressionAst] -and
                    $Ast.Member.Value -like 'Add_*'
            }, $true)

            foreach ($EventRegistrationExpression in $EventRegistrationExpressions) {
                $HandlerExpressionAst = $EventRegistrationExpression.Arguments |
                    Where-Object { $_ -is [ScriptBlockExpressionAst] } |
                    Select-Object -First 1

                if ($HandlerExpressionAst) {
                    $HandlerScriptBlocks += $HandlerExpressionAst.ScriptBlock
                }
            }

            # Search each handler script block for known blocking commands
            $MatchingNodes = foreach ($HandlerScriptBlock in $HandlerScriptBlocks) {
                $HandlerScriptBlock.FindAll({
                    param($Ast)

                    if ($Ast -isnot [CommandAst]) {
                        return $false
                    }

                    $CommandName = $Ast.GetCommandName()
                    foreach ($KnownBlockingCommand in $KnownBlockingCommands) {
                        if ($CommandName -like $KnownBlockingCommand) {
                            return $true
                        }
                    }

                    return $false
                }, $false)  # Search only the immediate script block, not nested ones
            }

            # Ensure violations appear in the order they occur in the script
            # despite the order they were collected in
            $MatchingNodes = $MatchingNodes | Sort-Object { $_.Extent.StartOffset }

            $MatchingNodes | ForEach-Object {
                $BadNode = $_

                $FilePath = if ($BadNode.Extent.FileName) {
                    $BadNode.Extent.FileName
                } else {
                    Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1 -ExpandProperty ScriptName
                }
                if (-not $FilePath) { $FilePath = '<ScriptBlock>' }

                $Finding = New-NitpickFinding `
                    -RuleName $PSCmdlet.MyInvocation.MyCommand.Name `
                    -Message "Avoid synchronous blocking commands in UI handlers." `
                    -Explanation $Metadata.Explanation `
                    -ViolationExtent $BadNode.Extent `
                    -Severity $Metadata.Severity `
                    -Category $Metadata.Category `
                    -RuleSuppressionID $Metadata.Name `
                    -ScriptPath $FilePath

                Write-Output $Finding
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
