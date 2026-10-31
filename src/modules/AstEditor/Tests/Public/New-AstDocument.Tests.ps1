using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'New-AstDocument' {
    It 'parses string input via InputObject' {
        $Overlay = New-AstDocument -InputObject 'Window Main { }'

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'wraps ScriptBlock input passed via InputObject' {
        $Overlay = New-AstDocument -InputObject {
            function Get-Greeting { 'hello' }
        }
        $Functions = @($Overlay.Ast.FindAll({
                    param($Node)
                    $Node -is [FunctionDefinitionAst]
                }, $true))

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast.Extent.StartOffset | Should -Be 0
        $Functions.Name | Should -Be 'Get-Greeting'
    }

    It 'wraps Ast input passed via InputObject' {
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput("Window Main { }", [ref] $Tokens, [ref] $Errors)

        $Overlay = New-AstDocument -InputObject $Ast

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast | Should -Not -Be $Ast
        $Overlay.Ast.Extent.StartOffset | Should -Be 0
        $Overlay.OriginalText | Should -Be 'Window Main { }'
    }

    It 'returns an existing AstDocument without coercing or reparsing it' {
        $Original = New-AstDocument -InputObject 'function Get-Greeting { ''hello'' }'

        $Resolved = New-AstDocument -InputObject $Original

        $Resolved | Should -Be $Original
    }

    It 'accepts pipeline input via InputObject' {
        $Overlay = 'Window Main { }' | New-AstDocument

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'processes every pipeline input object' {
        $Overlays = @('function Get-One {}', 'function Get-Two {}') |
            New-AstDocument

        $Overlays.Count | Should -Be 2
        $Overlays[0].OriginalText | Should -Be 'function Get-One {}'
        $Overlays[1].OriginalText | Should -Be 'function Get-Two {}'
    }
}
