using namespace System.Management.Automation.Language

Describe 'Test-AvoidBlockingUI' -Tag 'Test-AvoidBlockingUI' {
    BeforeAll {
        Import-Module -Name "Nitpick" -Force
        Import-Module -Name "$PSScriptRoot/../.."
    }

    It 'reports blocking commands beneath recognized UI handlers' {
        $ScriptBlockAst = {
            Window {
                On Loaded {
                    Start-Sleep -Seconds 1
                }

                $this.Add_Click({
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

        $Result = @(Test-AvoidBlockingUI -ScriptBlockAst $ScriptBlockAst)

        $Result.Count | Should -Be 4
        @($Result.ViolationExtent.Text) | Should -Be @(
            'Start-Sleep -Seconds 1'
            'Start-Sleep -Seconds 1'
            'Start-Sleep -Seconds 1'
            'Wait-Longer'
        )
    }

    It 'reports command extents when analyzing an inner handler script block' {
        $ScriptBlockAst = {
            On Click {
                Start-Sleep -Seconds 1
                if ($ReallyTired) {
                    Wait-Longer
                }
            }
        }.Ast
        $HandlerCommand = $ScriptBlockAst.Find({
            param($Ast)

            $Ast -is [CommandAst] -and $Ast.GetCommandName() -eq 'On'
        }, $true)
        $HandlerScriptBlock = ($HandlerCommand.CommandElements |
            Where-Object { $_ -is [ScriptBlockExpressionAst] } |
            Select-Object -First 1).ScriptBlock

        $Result = @(Test-AvoidBlockingUI -ScriptBlockAst $HandlerScriptBlock)

        $Result.Count | Should -Be 2
        @($Result.ViolationExtent.Text) | Should -Be @(
            'Start-Sleep -Seconds 1'
            'Wait-Longer'
        )
    }

    It 'reports command extents when analyzing an Add_Click script block' {
        $ScriptBlockAst = {
            $this.Add_Click({
                Start-Sleep -Seconds 1
            })
        }.Ast
        $EventRegistration = $ScriptBlockAst.Find({
            param($Ast)

            $Ast -is [InvokeMemberExpressionAst] -and $Ast.Member.Value -eq 'Add_Click'
        }, $true)
        $HandlerScriptBlock = ($EventRegistration.Arguments |
            Where-Object { $_ -is [ScriptBlockExpressionAst] } |
            Select-Object -First 1).ScriptBlock

        $Result = @(Test-AvoidBlockingUI -ScriptBlockAst $HandlerScriptBlock)

        $Result.Count | Should -Be 1
        $Result[0].ViolationExtent.Text | Should -Be 'Start-Sleep -Seconds 1'
    }
}
