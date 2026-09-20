BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickFinding' {
    BeforeEach {
        $Extent = { $Value }.Ast.EndBlock.Statements[0].Extent
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.'
    }

    It 'creates a Nitpick finding from a scalar correction' {
        $Finding = New-NitpickFinding `
            -RuleName Test-Rule `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Warning `
            -RuleSuppressionID NPTestRule `
            -Corrections $Correction

        $Finding.GetType().Name | Should -Be 'NitpickFinding'
        $Finding.RuleName | Should -Be 'Test-Rule'
        $Finding.Severity | Should -Be 'Warning'
        $Finding.Corrections.Count | Should -Be 1
        $Finding.Corrections[0] | Should -Be $Correction
    }

    It 'converts a finding to a ScriptAnalyzer DiagnosticRecord' {
        $Finding = New-NitpickFinding `
            -RuleName Test-Rule `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID NPTestRule `
            -Corrections $Correction `
            -OutputAs DiagnosticRecord

        $Finding.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
        $Finding.Message | Should -Be 'A problem was found.'
        $Finding.RuleName | Should -Be 'Test-Rule'
        $Finding.Severity.ToString() | Should -Be 'Information'
        $Finding.RuleSuppressionID | Should -Be 'NPTestRule'
        $Finding.SuggestedCorrections.Count | Should -Be 1
    }
}
