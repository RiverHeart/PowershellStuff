using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Find-AstToken' {
    It 'returns the first matching token by kind in source order' {
        $Document = New-AstDocument -InputObject '! $First; ! $Second'

        $Token = Find-AstToken -Document $Document -Kind Exclaim

        $Token.Kind | Should -Be ([TokenKind]::Exclaim)
        $Token.Extent.StartOffset | Should -Be 0
    }

    It 'returns all matching tokens when requested' {
        $Document = New-AstDocument -InputObject '! $First; ! $Second'

        $Tokens = @(Find-AstToken -Document $Document -Kind Exclaim -All)

        $Tokens | Should -HaveCount 2
        $Tokens[0].Extent.StartOffset | Should -BeLessThan $Tokens[1].Extent.StartOffset
    }

    It 'finds tokens nested inside expandable strings' {
        $Document = New-AstDocument -InputObject '"outer $(-not (! $Value))"'

        @(Find-AstToken -Document $Document -Kind Exclaim, Not -All).Kind |
            Should -Be @([TokenKind]::Not, [TokenKind]::Exclaim)
    }

    It 'limits matches to tokens fully contained in an extent' {
        $Document = New-AstDocument -InputObject '! $First; ! $Second'
        $Second = $Document.Ast.EndBlock.Statements[1].PipelineElements[0].Expression

        $Token = Find-AstToken -Document $Document -Kind Exclaim -Range $Second.Extent

        $Token.Extent.StartOffset | Should -Be $Second.Extent.StartOffset
    }

    It 'supports offset ranges and query predicates' {
        $Document = New-AstDocument -InputObject '! $First; ! $Second'

        $Tokens = @(Find-AstToken `
            -Document $Document `
            -Kind Exclaim `
            -Range @(10, $Document.OriginalText.Length) `
            -Query { $_.Extent.StartOffset -ge 10 } `
            -All)

        $Tokens | Should -HaveCount 1
        $Tokens[0].Text | Should -BeExactly '!'
    }

    It 'rejects invalid ranges' {
        $Document = New-AstDocument -InputObject '! $Value'

        { Find-AstToken -Document $Document -Range @(1, 0) } |
            Should -Throw '*non-negative and ordered*'
        { Find-AstToken -Document $Document -Range @('one', 'two') } |
            Should -Throw '*two-item integer offset range*'
    }

    It 'rejects ambiguous query output' {
        $Document = New-AstDocument -InputObject '! $Value'

        { Find-AstToken -Document $Document -Kind Exclaim -Query { $true, $false } } |
            Should -Throw '*emitted 2 values*'
    }
}
