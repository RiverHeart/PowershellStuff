BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickCorrection' {
    BeforeAll {
        $Extent = { $Value }.Ast.EndBlock.Statements[0].Extent
    }

    It 'creates a Nitpick correction from an extent' {
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.'

        $Correction.GetType().Name | Should -Be 'NitpickCorrection'
        $Correction.StartLineNumber | Should -Be $Extent.StartLineNumber
        $Correction.ReplacementText | Should -Be '$Replacement'
        $Correction.Description | Should -Be 'Replace the value.'
    }

    It 'creates a Nitpick correction from line and column positions' {
        $Correction = New-NitpickCorrection `
            -StartLineNumber 1 `
            -EndLineNumber 2 `
            -StartColumnNumber 3 `
            -EndColumnNumber 4 `
            -ReplacementText 'replacement' `
            -FilePathOrContext 'Test.ps1' `
            -Description 'Replace text.'

        $Correction.StartLineNumber | Should -Be 1
        $Correction.EndLineNumber | Should -Be 2
        $Correction.StartColumnNumber | Should -Be 3
        $Correction.EndColumnNumber | Should -Be 4
    }

    It 'converts a correction to a ScriptAnalyzer CorrectionExtent' {
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.' `
            -OutputAs CorrectionExtent

        $Correction.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent'
        $Correction.Text | Should -Be '$Replacement'
        $Correction.Description | Should -Be 'Replace the value.'
    }
}
