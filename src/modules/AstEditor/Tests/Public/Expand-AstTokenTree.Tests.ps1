using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Expand-AstTokenTree' {
    BeforeEach {
        $RootTokens = $null
        $ParseErrors = $null
        [void] [Parser]::ParseInput(
            '"outer $("inner $(! $Value)")"',
            [ref] $RootTokens,
            [ref] $ParseErrors
        )
    }

    It 'recursively returns expandable-string tokens in source order' {
        $Tokens = @(Expand-AstTokenTree -Token $RootTokens)

        $ParseErrors | Should -BeNullOrEmpty
        @($Tokens | Where-Object { $_ -is [StringExpandableToken] }) |
            Should -HaveCount 2
        @($Tokens | Where-Object { $_.Kind -eq [TokenKind]::Exclaim }) |
            Should -HaveCount 1
        @($Tokens | Where-Object { $_.Kind -eq [TokenKind]::Variable }).Text |
            Should -BeExactly '$Value'

        for ($Index = 1; $Index -lt $Tokens.Count; $Index++) {
            $Tokens[$Index].Extent.StartOffset |
                Should -BeGreaterOrEqual $Tokens[$Index - 1].Extent.StartOffset
        }
    }

    It 'accepts parser tokens from the pipeline' {
        $Tokens = @($RootTokens | Expand-AstTokenTree)

        $Tokens.Count | Should -BeGreaterThan $RootTokens.Count
    }

    It 'accepts an empty token collection' {
        @(Expand-AstTokenTree -Token @()) | Should -HaveCount 0
    }
}
