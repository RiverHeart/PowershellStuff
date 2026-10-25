BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Format-NitpickText' {
    It 'displays line:column while linking to the file URI with line:column' {
        $PreviousForceHyperlink = $env:FORCE_HYPERLINK
        try {
            $env:FORCE_HYPERLINK = '1'
            $Text = InModuleScope Nitpick -Parameters @{ FilePath = $PSCommandPath } {
                param ($FilePath)

                $Tokens = $null
                $Errors = $null
                $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
                    '  $Value = 1', $FilePath, [ref] $Tokens, [ref] $Errors
                )
                $Finding = New-NitpickFinding -RuleName TestRule -RuleSuppressionID TestRule `
                    -Message 'Test message' -Severity Warning `
                    -ViolationExtent $Ast.EndBlock.Statements[0].Extent `
                    -ScriptPath $FilePath -Explanation 'Test finding'

                Format-NitpickText -Ast $Ast -Finding $Finding
            }
        } finally {
            $env:FORCE_HYPERLINK = $PreviousForceHyperlink
        }

        $Esc = [char] 27
        $Uri = [Uri]::new($PSCommandPath).AbsoluteUri
        $ExpectedLink = @(
            $Esc, ']8;;', $Uri, '#1:3', $Esc, '\', '1:3', $Esc, ']8;;', $Esc, '\'
        ) -join ''
        $Text.Contains($ExpectedLink) |
            Should -BeTrue -Because 'the link target and visible text should both include line:column'
    }
}
