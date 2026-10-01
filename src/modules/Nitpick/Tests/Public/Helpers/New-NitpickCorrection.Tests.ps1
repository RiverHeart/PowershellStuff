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
        $Correction.StartOffset | Should -Be $Extent.StartOffset
        $Correction.EndOffset | Should -Be $Extent.EndOffset
        $Correction.HasOffsets | Should -BeTrue
        $Correction.ExpectedText | Should -Be $Extent.Text
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
        $Correction.HasOffsets | Should -BeFalse
        $Correction.StartOffset | Should -Be -1
        $Correction.ExpectedText | Should -BeNullOrEmpty
    }

    It 'creates a correction from explicit offsets' {
        $Correction = New-NitpickCorrection `
            -StartLineNumber 1 `
            -EndLineNumber 1 `
            -StartColumnNumber 2 `
            -EndColumnNumber 4 `
            -StartOffset 1 `
            -EndOffset 3 `
            -ExpectedText 'bc' `
            -ReplacementText 'BC' `
            -FilePathOrContext 'Test.ps1' `
            -Description 'Replace text.' `
            -Applicability Review `
            -GroupId 'group-1' `
            -RuleName 'ExampleRule'

        $Correction.HasOffsets | Should -BeTrue
        $Correction.StartOffset | Should -Be 1
        $Correction.EndOffset | Should -Be 3
        $Correction.ExpectedText | Should -Be 'bc'
        $Correction.Applicability | Should -Be 'Review'
        $Correction.GroupId | Should -Be 'group-1'
        $Correction.RuleName | Should -Be 'ExampleRule'
    }

    It 'supports insertion and multiline offset ranges' {
        $Insertion = New-NitpickCorrection `
            -StartLineNumber 1 -EndLineNumber 1 `
            -StartColumnNumber 1 -EndColumnNumber 1 `
            -StartOffset 0 -EndOffset 0 `
            -ExpectedText '' -ReplacementText 'prefix' `
            -FilePathOrContext '<ScriptBlock>' -Description 'Insert a prefix.'
        $Multiline = New-NitpickCorrection `
            -StartLineNumber 1 -EndLineNumber 2 `
            -StartColumnNumber 1 -EndColumnNumber 2 `
            -StartOffset 0 -EndOffset 4 `
            -ExpectedText "a`r`nb" -ReplacementText 'c' `
            -FilePathOrContext '<ScriptBlock>' -Description 'Replace multiline text.'

        $Insertion.ExpectedText | Should -Be ''
        $Insertion.StartOffset | Should -Be $Insertion.EndOffset
        $Multiline.ExpectedText | Should -Be "a`r`nb"
    }

    It 'rejects invalid offset and coordinate ranges' {
        {
            New-NitpickCorrection `
                -StartLineNumber 1 -EndLineNumber 1 `
                -StartColumnNumber 4 -EndColumnNumber 2 `
                -StartOffset 3 -EndOffset 1 `
                -ExpectedText '' -ReplacementText 'x' `
                -FilePathOrContext '<ScriptBlock>' -Description 'Invalid range.'
        } | Should -Throw
    }

    It 'rejects expected text whose length does not match the offset range' {
        {
            New-NitpickCorrection `
                -StartLineNumber 1 -EndLineNumber 1 `
                -StartColumnNumber 1 -EndColumnNumber 3 `
                -StartOffset 0 -EndOffset 2 `
                -ExpectedText 'x' -ReplacementText 'X' `
                -FilePathOrContext '<ScriptBlock>' -Description 'Mismatched text.'
        } | Should -Throw '*ExpectedText length must match*'
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
