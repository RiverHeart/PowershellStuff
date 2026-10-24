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
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction `
            -OutputAs NitpickFinding

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
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
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

    It 'defaults to a ScriptAnalyzer diagnostic outside a Nitpick invocation' {
        $Finding = New-NitpickFinding `
            -RuleName Test-Rule `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID NPTestRule `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction

        $Finding.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
    }

    It 'omits coordinated corrections while preserving ungrouped suggestions' -ForEach @(
        @{ OutputAs = 'NitpickFinding' }
        @{ OutputAs = 'DiagnosticRecord' }
    ) {
        $GroupedCorrections = @(
            New-NitpickCorrection `
                -ViolationExtent $Extent `
                -ReplacementText '$First' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'First coordinated edit.' `
                -ChangeSetId 'TestRule:0'
            New-NitpickCorrection `
                -ViolationExtent $Extent `
                -ReplacementText '$Second' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Second coordinated edit.' `
                -ChangeSetId 'TestRule:0'
        )
        $Finding = New-NitpickFinding `
            -RuleName Test-Rule `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID NPTestRule `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections (@($Correction) + $GroupedCorrections) `
            -OutputAs $OutputAs

        $Diagnostic = if ($OutputAs -eq 'NitpickFinding') {
            $Finding.Corrections | Should -HaveCount 3
            $Finding.ToDiagnosticRecord()
        } else {
            $Finding
        }

        $Diagnostic.SuggestedCorrections | Should -HaveCount 1
        $Diagnostic.SuggestedCorrections[0].Text | Should -BeExactly '$Replacement'
    }

    It 'converts a finding with a null rule suppression ID' {
        $Finding = New-NitpickFinding `
            -RuleName Test-Rule `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Warning `
            -RuleSuppressionID NPTestRule `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction `
            -OutputAs NitpickFinding
        $Finding.RuleSuppressionID = $null

        $DiagnosticRecord = $Finding.ToDiagnosticRecord()

        $DiagnosticRecord.RuleSuppressionID | Should -BeNullOrEmpty
        $DiagnosticRecord.SuggestedCorrections.Count | Should -Be 1
    }
}
