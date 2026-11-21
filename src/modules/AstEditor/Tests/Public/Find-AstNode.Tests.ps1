using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Find-AstNode' {
    It 'is exported under its primary name' {
        (Get-Command Find-AstNode).ModuleName | Should -Be 'AstEditor'
        @(Get-Command -Module AstEditor).Name | Should -Contain 'Find-AstNode'
        @(Get-Command -Module AstEditor).Name | Should -Not -Contain 'Find-AEAstNode'
    }

    It 'rejects Query scriptblocks that emit multiple values' {
        {
            $FindParams = @{
                ScriptBlock = { Write-Host 'one' }
                Type = 'CommandAst'
                Query = { $_; $true }
                ErrorAction = 'Stop'
            }
            Find-AstNode @FindParams
        } | Should -Throw '*Find-AstNode query emitted 2 values*CommandAst*'
    }

    It 'searches an existing document without changing node identity' {
        $Document = New-AstDocument -InputObject 'Get-One; Get-Two'
        $Nodes = @(AstEditor\Find-AstNode -Document $Document -Type CommandAst -All)
        $Nodes | Should -HaveCount 2
        [object]::ReferenceEquals($Nodes[0], $Document.Ast.EndBlock.Statements[0].PipelineElements[0]) |
            Should -BeTrue
    }

    It 'accepts an extent or a two-integer range and returns contained nodes' {
        $Document = New-AstDocument -InputObject 'Get-One; Get-Two'
        $Extent = $Document.Ast.EndBlock.Statements[1].Extent
        foreach ($Range in @($Extent, @($Extent.StartOffset, $Extent.EndOffset))) {
            $Nodes = @(AstEditor\Find-AstNode -Document $Document -Type CommandAst -Range $Range -All)
            $Nodes | Should -HaveCount 1
            $Nodes[0].GetCommandName() | Should -Be 'Get-Two'
        }
        @(AstEditor\Find-AstNode -Document $Document -Type CommandAst -Range @(1, 3) -All) |
            Should -HaveCount 0
    }

    It 'rejects invalid ranges rather than coercing them' {
        foreach ($Range in @($null, 1, @(0), @(0, 1, 2), @('0', '1'), @(-1, 1), @(2, 1))) {
            {
                $FindParams = @{
                    ScriptBlock = { Get-One }
                    Range = $Range
                    ErrorAction = 'Stop'
                }
                AstEditor\Find-AstNode @FindParams
            } | Should -Throw '*Range*'
        }
    }
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
        $Overlay.Ast.Extent.StartOffset | Should -BeGreaterThan 0
        $Overlay.IsFragment | Should -BeTrue
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
