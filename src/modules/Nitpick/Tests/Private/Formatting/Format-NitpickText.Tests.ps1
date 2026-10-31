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

    It 'renders findings and corrections beneath one target header' {
        $PreviousNoHyperlink = $env:NO_HYPERLINK
        try {
            $env:NO_HYPERLINK = '1'
            $Text = InModuleScope Nitpick -Parameters @{ FilePath = $PSCommandPath } {
                param ($FilePath)

                $Tokens = $null
                $Errors = $null
                $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
                    '$Value = 1', $FilePath, [ref] $Tokens, [ref] $Errors
                )
                $Finding = New-NitpickFinding -RuleName TestRule -RuleSuppressionID TestRule `
                    -Message 'Test message' -Severity Warning `
                    -ViolationExtent $Ast.EndBlock.Statements[0].Extent `
                    -ScriptPath $FilePath -Explanation 'Test finding'
                $Correction = New-NitpickCorrection -ViolationExtent $Ast.Extent `
                    -ReplacementText '$Value = 2' -FilePathOrContext $FilePath -Description 'Reason'
                $Proposal = [NitpickCorrectionProposal]@{
                    Status = 'Ready'
                    AcceptedCorrections = @($Correction)
                    SkippedCorrections = @()
                    Conflicts = @()
                    Diff = "1:1  Reason`n  1 - old`n    + new"
                }
                $CorrectionResult = New-NitpickCorrectionResult -Path $FilePath -Proposal $Proposal `
                    -Application @{ Status = 'Preview' }

                Format-NitpickText -Ast $Ast -Finding $Finding -CorrectionResult $CorrectionResult
            }
        } finally {
            $env:NO_HYPERLINK = $PreviousNoHyperlink
        }

        $Lines = $Text -split '\r?\n'
        $Lines[0] | Should -BeExactly $PSCommandPath
        $Lines[1] | Should -Match '^  1:1  warning  Test message  '
        $Lines[2..($Lines.Count - 1)] | Should -BeExactly @(
            '', '  1:1  Reason', '    1 - old', '      + new', '', '  1 proposed correction.'
        )
        @($Lines | Where-Object { $_ -eq $PSCommandPath }).Count | Should -Be 1
    }

    It 'returns nothing without findings or correction activity' {
        InModuleScope Nitpick {
            Format-NitpickText -Ast {}.Ast -Finding @()
        } | Should -BeNullOrEmpty
    }
}
