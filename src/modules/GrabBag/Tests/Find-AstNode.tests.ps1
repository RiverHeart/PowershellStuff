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
}
