BeforeAll {
    $AdapterManifest = Join-Path $PSScriptRoot '..\Nitpick.ScriptAnalyzer.psd1'
    Import-Module $AdapterManifest -Force -ErrorAction Stop
}

Describe 'Nitpick.ScriptAnalyzer native boundary' {
    It 'keeps ScriptAnalyzer types out of native finding classes' {
        InModuleScope Nitpick {
            [NitpickFinding].GetMethod('ToDiagnosticRecord') | Should -BeNullOrEmpty
            [NitpickCorrection].GetMethod('ToCorrectionExtent') | Should -BeNullOrEmpty
        }
    }

    It 'does not add PSScriptAnalyzer output options to native helpers' {
        (Get-Command New-NitpickFinding).Parameters.ContainsKey('OutputAs') |
            Should -BeFalse
        (Get-Command New-NitpickCorrection).Parameters.ContainsKey('OutputAs') |
            Should -BeFalse
    }

    It 'does not require the adapter to invoke native Nitpick rules' {
        $Diagnostic = @(Start-Nitpicking `
            -Script '$Value = -not ($Other -is [string])' `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary)

        $Diagnostic | Should -HaveCount 1
        $Diagnostic[0].GetType().Name | Should -BeExactly 'NitpickFinding'
    }
}
