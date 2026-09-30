BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

BeforeDiscovery {
    $SeverityRanks = @{
        Information = 0
        Warning = 1
        Error = 2
    }
    $SeverityThresholdCases = foreach ($ErrorOn in 'Information', 'Warning', 'Error') {
        foreach ($FindingSeverity in 'Information', 'Warning', 'Error') {
            @{
                ErrorOn = $ErrorOn
                FindingSeverity = $FindingSeverity
                ShouldError = $SeverityRanks[$FindingSeverity] -ge $SeverityRanks[$ErrorOn]
            }
        }
    }
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
                -IncludeRule AvoidParameterAttributeBool `
                -Output Object
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
                -Output Object `
                -NoSummary
        )

        $Results.Count | Should -Be 1
        $Results[0].GetType().Name | Should -Be 'NitpickFinding'
    }

    It 'returns finding and summary text by default' {
        $Script = [scriptblock]::Create(
            'param([Parameter(Mandatory=$true)] [string] $Name)'
        )
        $Results = @(
            Start-Nitpicking `
                -Script $Script.Ast `
                -IncludeRule AvoidParameterAttributeBool
        )

        $Results.Count | Should -Be 2
        $Results[0] | Should -BeOfType ([string])
        $Results[0] | Should -Match '^<ScriptBlock>:\d+:\d+: Information AvoidParameterAttributeBool:'
        $Results[1] | Should -BeOfType ([string])
        $Results[1] | Should -Match '^1 finding \(0 errors, 0 warnings, 1 information\) across 1 target in [\d,]+ ms$'
    }

    It 'errors for <FindingSeverity> findings at the <ErrorOn> threshold: <ShouldError>' -ForEach $SeverityThresholdCases {
        $RuleName = "Threshold$FindingSeverity"
        $RuleSeverity = $FindingSeverity
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            New-NitpickFinding `
                -RuleName $RuleName `
                -Message 'Threshold test finding' `
                -ViolationExtent $ScriptBlockAst.Extent `
                -Severity $RuleSeverity `
                -RuleSuppressionID $RuleName `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Threshold test finding' `
                -OutputAs NitpickFinding
        }.GetNewClosure()

        Register-Nitpick -Callable $Rule -Name $RuleName -Source Tests

        $ThresholdErrors = @()
        $null = Start-Nitpicking `
            -Script {} `
            -IncludeRule $RuleName `
            -ErrorOn $ErrorOn `
            -NoSummary `
            -ErrorAction SilentlyContinue `
            -ErrorVariable ThresholdErrors

        ($ThresholdErrors.Count -gt 0) | Should -Be $ShouldError
    }
}
