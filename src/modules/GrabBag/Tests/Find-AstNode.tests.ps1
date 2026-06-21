BeforeAll {
    Import-Module "$PSScriptRoot/.." -Force
}

Describe 'Find-AstNode' {
    It 'returns the first matching node when Type is provided' {
        $Node = Find-AstNode -ScriptBlock { Write-Host 'one'; Get-Date } -Type CommandAst

        $Node | Should -Not -BeNullOrEmpty
        $Node | Should -BeOfType ([System.Management.Automation.Language.CommandAst])
        $Node.GetCommandName() | Should -Be 'Write-Host'
    }

    It 'returns all matching nodes when All is set' {
        $Nodes = Find-AstNode -ScriptBlock { Write-Host 'one'; Get-Date } -Type CommandAst -All

        $Nodes.Count | Should -Be 2
        $Nodes[0].GetCommandName() | Should -Be 'Write-Host'
        $Nodes[1].GetCommandName() | Should -Be 'Get-Date'
    }

    It 'supports the Ast parameter set' {
        $Ast = ([scriptblock]::Create("Write-Host 'one'; Get-Date")).Ast

        $Node = Find-AstNode -Ast $Ast -Type CommandAst

        $Node | Should -Not -BeNullOrEmpty
        $Node.GetCommandName() | Should -Be 'Write-Host'
    }

    It 'combines Type and Query filters' {
        $Node = Find-AstNode -ScriptBlock { Write-Host 'one'; Get-Date } -Type CommandAst -Query {
            $_.GetCommandName() -eq 'Get-Date'
        }

        $Node | Should -Not -BeNullOrEmpty
        $Node.GetCommandName() | Should -Be 'Get-Date'
    }

    It 'supports Query scriptblocks that use a param block' {
        $Node = Find-AstNode -ScriptBlock { Write-Host 'one'; Get-Date } -Type CommandAst -Query {
            param($AstNode)
            $AstNode.GetCommandName() -eq 'Get-Date'
        }

        $Node | Should -Not -BeNullOrEmpty
        $Node.GetCommandName() | Should -Be 'Get-Date'
    }

    It 'returns null when no node matches the combined filters' {
        $Node = Find-AstNode -ScriptBlock { Write-Host 'one'; Get-Date } -Type CommandAst -Query {
            $_.GetCommandName() -eq 'Get-Process'
        }

        $Node | Should -Be $null
    }

    It 'respects Recurse for nested command discovery' {
        $Source = {
            & {
                Write-Host 'nested'
            }
        }

        $WithoutRecurse = Find-AstNode -ScriptBlock $Source -Type CommandAst -All
        $WithRecurse = Find-AstNode -ScriptBlock $Source -Type CommandAst -All -Recurse

        $WithoutRecurse.Count | Should -Be 1
        $WithRecurse.Count | Should -Be 2
        $WithoutRecurse[0].Extent.Text | Should -Match '^&\s*\{'
        ($WithRecurse | Where-Object { $_.GetCommandName() -eq 'Write-Host' }).Count | Should -Be 1
    }

    It 'filters nodes whose extents contain the specified cursor offset' {
        $Source = {
            & {
                Write-Host 'nested'
            }
        }

        $Ast = $Source.Ast
        $InnerNode = Find-AstNode -Ast $Ast -Type CommandAst -Recurse -Query {
            $_.GetCommandName() -eq 'Write-Host'
        }
        $CursorOffset = $InnerNode.Extent.StartOffset + 1

        $Nodes = Find-AstNode -Ast $Ast -Type CommandAst -All -Recurse -ContainsCursor -CursorOffset $CursorOffset

        $Nodes.Count | Should -Be 2
        ($Nodes | Where-Object { $_.GetCommandName() -eq 'Write-Host' }).Count | Should -Be 1
        ($Nodes | Where-Object {
            $_.Extent.StartOffset -le $CursorOffset -and
            $CursorOffset -le $_.Extent.EndOffset
        }).Count | Should -Be 2
    }

    It 'composes ContainsCursor with Query filtering' {
        $Source = {
            & {
                Write-Host 'nested'
            }
        }

        $Ast = $Source.Ast
        $InnerNode = Find-AstNode -Ast $Ast -Type CommandAst -Recurse -Query {
            $_.GetCommandName() -eq 'Write-Host'
        }
        $CursorOffset = $InnerNode.Extent.StartOffset + 1

        $Node = Find-AstNode -Ast $Ast -Type CommandAst -Recurse -ContainsCursor -CursorOffset $CursorOffset -Query {
            $_.GetCommandName() -eq 'Write-Host'
        }

        $Node | Should -Not -BeNullOrEmpty
        $Node.GetCommandName() | Should -Be 'Write-Host'
    }

    It 'requires CursorOffset when ContainsCursor is specified and cannot be auto-resolved' {
        {
            Find-AstNode -ScriptBlock { Write-Host 'one' } -Type CommandAst -ContainsCursor
        } | Should -Throw '*CursorOffset is required when ContainsCursor is specified and could not be resolved from TabExpansion2 context.*'
    }

    It 'requires ContainsCursor when CursorOffset is specified' {
        {
            Find-AstNode -ScriptBlock { Write-Host 'one' } -Type CommandAst -CursorOffset 0
        } | Should -Throw '*ContainsCursor is required when CursorOffset is specified.*'
    }

    It 'auto-resolves CursorOffset from TabExpansion2 callstack when ContainsCursor is specified' {
        $Source = {
            & {
                Write-Host 'nested'
            }
        }

        $Ast = $Source.Ast
        $InnerNode = Find-AstNode -Ast $Ast -Type CommandAst -Recurse -Query {
            $_.GetCommandName() -eq 'Write-Host'
        }
        $CursorOffset = $InnerNode.Extent.StartOffset + 1

        Mock -ModuleName GrabBag -CommandName Get-PSCallStack -MockWith {
            @(
                [pscustomobject] @{
                    Command = 'TabExpansion2'
                    InvocationInfo = [pscustomobject] @{
                        BoundParameters = [pscustomobject] @{
                            PositionOfCursor = [pscustomobject] @{ Offset = $CursorOffset }
                        }
                    }
                }
            )
        }

        {
            $Nodes = Find-AstNode -Ast $Ast -Type CommandAst -All -Recurse -ContainsCursor

            $Nodes.Count | Should -Be 2
            ($Nodes | Where-Object { $_.GetCommandName() -eq 'Write-Host' }).Count | Should -Be 1
        } | Should -Not -Throw
    }

    It 'auto-resolves Ast and CursorOffset from TabExpansion2 callstack when ContainsCursor is specified' {
        $Source = {
            & {
                Write-Host 'nested'
            }
        }

        $Ast = $Source.Ast
        $InnerNode = Find-AstNode -Ast $Ast -Type CommandAst -Recurse -Query {
            $_.GetCommandName() -eq 'Write-Host'
        }
        $CursorOffset = $InnerNode.Extent.StartOffset + 1

        Mock -ModuleName GrabBag -CommandName Get-PSCallStack -MockWith {
            @(
                [pscustomobject] @{
                    Command = 'TabExpansion2'
                    InvocationInfo = [pscustomobject] @{
                        BoundParameters = [pscustomobject] @{
                            Ast = $Ast
                            PositionOfCursor = [pscustomobject] @{ Offset = $CursorOffset }
                        }
                    }
                }
            )
        }

        $Nodes = Find-AstNode -Type CommandAst -All -Recurse -ContainsCursor

        $Nodes.Count | Should -Be 2
        ($Nodes | Where-Object { $_.GetCommandName() -eq 'Write-Host' }).Count | Should -Be 1
    }
}
