BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'filters paths using wildcard include and exclude patterns' {
        $IncludedPath = Join-Path $TestDrive 'included.ps1'
        $ExcludedPath = Join-Path $TestDrive 'excluded.ps1'
        $RuleViolation = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        Set-Content -Path $IncludedPath -Value $RuleViolation
        Set-Content -Path $ExcludedPath -Value "$RuleViolation`n$RuleViolation"

        $Results = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludePath '*.ps1' `
                -ExcludePath '*excluded.ps1' `
                -IncludeRule AvoidParameterAttributeBool
        )

        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Findings.Count | Should -Be 1
        $Summary.TargetCount | Should -Be 1
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
        $Summary.InformationCount | Should -Be 1
    }

    It 'returns only findings when NoSummary is specified' {
        $Results = @(
            Start-Nitpicking `
                -Script { param([Parameter(Mandatory=$true)] [string] $Name) } `
                -IncludeRule AvoidParameterAttributeBool `
                -NoSummary
        )

        $Results.Count | Should -Be 1
        $Results[0].GetType().Name | Should -Be 'NitpickFinding'
    }
}
