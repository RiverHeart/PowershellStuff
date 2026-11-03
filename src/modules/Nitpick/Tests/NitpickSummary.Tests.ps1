BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\Nitpick.psd1" -Force

    function New-TestSummary {
        param ([hashtable] $Values)

        $Summary = & (Get-Module Nitpick) { [NitpickSummary]::new() }
        foreach ($Name in $Values.Keys) {
            $Summary.$Name = $Values[$Name]
        }
        $Summary
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'NitpickSummary formatting' {
    It 'defaults to FixMode Off with zeroed counters' {
        $Summary = New-TestSummary @{}

        $Summary.FixMode | Should -Be 'Off'
        $Summary.FindingCount | Should -Be 0
        $Summary.CorrectedFindingCount | Should -Be 0
        $Summary.CorrectableFindingCount | Should -Be 0
        $Summary.UnresolvedFindingCount | Should -Be 0
    }

    It 'formats <Label>' -ForEach @(
        @{
            Label = 'detected severities without zero counts or a correction clause'
            Values = @{
                FindingCount = 3; ErrorCount = 1; WarningCount = 2
                TargetCount = 2; Duration = [timespan]::FromMilliseconds(90)
            }
            Expected = '3 findings (1 error, 2 warnings) across 2 targets in 90 ms'
        }
        @{
            Label = 'an apply with corrected and unresolved counts'
            Values = @{
                FixMode = 'Apply'; FindingCount = 1; InformationCount = 1
                CorrectedFindingCount = 1; UnresolvedFindingCount = 0
                TargetCount = 1; Duration = [timespan]::FromMilliseconds(112)
            }
            Expected = '1 finding (1 information; 1 corrected, 0 unresolved) across 1 target in 112 ms'
        }
        @{
            Label = 'a preview with correctable findings'
            Values = @{
                FixMode = 'Preview'; FindingCount = 1; InformationCount = 1
                CorrectableFindingCount = 1; UnresolvedFindingCount = 0
                TargetCount = 1; Duration = [timespan]::FromMilliseconds(112)
            }
            Expected = '1 finding (1 information; 1 correctable, 0 unresolved) across 1 target in 112 ms'
        }
        @{
            Label = 'coexisting corrected and correctable findings after a declined or failed write'
            Values = @{
                FixMode = 'Apply'; FindingCount = 3; ErrorCount = 2; WarningCount = 1
                CorrectedFindingCount = 1; CorrectableFindingCount = 1; UnresolvedFindingCount = 2
                TargetCount = 2; Duration = [timespan]::FromMilliseconds(90)
            }
            Expected = '3 findings (2 errors, 1 warning; 1 corrected, 1 correctable, 2 unresolved) across 2 targets in 90 ms'
        }
        @{
            Label = 'a clean lint run without any parenthetical'
            Values = @{ TargetCount = 1; Duration = [timespan]::FromMilliseconds(5) }
            Expected = '0 findings across 1 target in 5 ms'
        }
        @{
            Label = 'a clean fix run with only the unresolved counter'
            Values = @{
                FixMode = 'Apply'; TargetCount = 1
                Duration = [timespan]::FromMilliseconds(5)
            }
            Expected = '0 findings (0 unresolved) across 1 target in 5 ms'
        }
    ) {
        (New-TestSummary $Values).ToString() | Should -BeExactly $Expected
    }
}
