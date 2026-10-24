BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking coordinated structural transactions' {
    It 'uses native nested traversal for initial analysis and fix reanalysis' {
        $Source = 'function Test-Value { param([Parameter(Mandatory=$true)] [string] $Name); -not ($Name -is [string]) }'
        $Rules = @('Nitpick/UseIsNotOperator', 'Nitpick/AvoidParameterAttributeBool')
        $Initial = @(Start-Nitpicking -Script $Source -IncludeRule $Rules -Output Object -NoSummary)
        $Initial | Should -HaveCount 2
        foreach ($Finding in $Initial) {
            $Finding.GetType().Name | Should -Be 'NitpickFinding'
        }

        $Output = @(Start-Nitpicking -Script $Source -IncludeRule $Rules -Fix -Output Object -NoSummary)
        $Result = $Output | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Proposal.OriginalFindings | Should -HaveCount 2
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 3
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 0
        $Result.Report.EffectiveText | Should -BeExactly 'function Test-Value { param([Parameter(Mandatory)] [string] $Name);  ($Name -isnot [string]) }'

    }

    It 'retains nested diagnostic-only findings during fix reanalysis' {
        $Source = 'function Test-Value { -not ($Name -is [string]); -not ($Name -is [string] > $null) }'
        $Output = @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/UseIsNotOperator -Fix -Output Object -NoSummary)
        $Result = $Output | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }

        $Result.Proposal.OriginalFindings | Should -HaveCount 2
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0].GetType().Name | Should -Be 'NitpickFinding'
        $Result.Report.EffectiveFindings[0].Corrections | Should -BeNullOrEmpty
        $Result.Report.EffectiveFindings[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        $Result.Proposal.SkippedCorrections | Should -HaveCount 0
    }

    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
        $Source = "# $([char]0x00E9)`r`n-not ('literal -is' -is [string]); -not (`$Value -is [int])`r`n"
        $Expected = "# $([char]0x00E9)`r`n ('literal -is' -isnot [string]);  (`$Value -isnot [int])`r`n"
        $Encoding = [System.Text.UTF8Encoding]::new($true, $true)
        $Path = Join-Path $TestDrive 'Structural.ps1'
        [System.IO.File]::WriteAllText($Path, $Source, $Encoding)
        $OriginalBytes = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
    }

    It 'returns in-memory candidate analysis without writing a file-backed Script AST' {
        $Ast = Import-ScriptBlockAst -FilePath $Path
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Memory input must not be saved.' }

        $Results = @(Start-Nitpicking -Script $Ast -IncludeRule Nitpick/UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Proposal.Document.IsFileBacked | Should -BeFalse
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.CandidateText | Should -BeExactly $Expected
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 4
        $Result.Proposal.OriginalFindings | Should -HaveCount 2

        $Result.Report.EffectiveFindings | Should -HaveCount 0
        $Result.Report.EffectiveText | Should -BeExactly $Expected

        $Summary.FindingCount | Should -Be 0
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 0

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes
    }

    It 'previews and commits equivalent groups with final counts and preserved bytes' {
        $PreviewOutput = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix -Preview `
            -Output Object -ErrorOn Information -ErrorAction Stop)

        $Preview = $PreviewOutput | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $PreviewSummary = $PreviewOutput | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Preview.Application.Status | Should -Be 'Preview'
        $Preview.Application.WriteResult | Should -BeNullOrEmpty
        $Preview.Application.CommittedCorrections | Should -HaveCount 0
        $Preview.Report.EffectiveText | Should -BeExactly $Expected
        $Preview.Report.FindingsWithCommittedCorrections | Should -HaveCount 0
        $Preview.Proposal.AcceptedCorrections | Should -HaveCount 4

        $PreviewSummary.FindingCount | Should -Be 0
        $PreviewSummary.FindingsWithCommittedCorrectionsCount | Should -Be 0

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes

        $ApplyOutput = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false -ErrorAction Stop)

        $Applied = $ApplyOutput | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $ApplyOutput | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Applied.Application.Status | Should -Be 'Written'
        $Applied.Application.WriteResult.WasWritten | Should -BeTrue

        $Applied.Proposal.WasReanalyzed | Should -BeTrue
        $Applied.Proposal.OriginalFingerprint | Should -BeExactly $Preview.Proposal.OriginalFingerprint
        $Applied.Proposal.Diff | Should -BeExactly $Preview.Proposal.Diff
        $Applied.Proposal.CandidateText | Should -BeExactly $Preview.Proposal.CandidateText
        $Applied.Proposal.AcceptedCorrections | Should -HaveCount 4

        $Applied.Report.EffectiveText | Should -BeExactly $Expected

        for ($Index = 0; $Index -lt 4; $Index++) {
            foreach ($Property in @('StartOffset', 'EndOffset', 'ExpectedText', 'ReplacementText', 'ChangeSetId', 'RuleName', 'RuleId')) {
                $Applied.Proposal.AcceptedCorrections[$Index].$Property |
                    Should -BeExactly $Preview.Proposal.AcceptedCorrections[$Index].$Property
            }
        }

        $Applied.Application.CommittedCorrections | Should -HaveCount 4
        $Applied.Report.FindingsWithCommittedCorrections | Should -HaveCount 2
        $Applied.Report.EffectiveFindings | Should -HaveCount 0
        $Summary.TargetCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        $Summary.InformationCount | Should -Be 0
        $Summary.WarningCount | Should -Be 0
        $Summary.ErrorCount | Should -Be 0
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 2
        $Summary.SkippedCorrectionCount | Should -Be 0
        $Summary.FailedTargetCount | Should -Be 0
        $ExpectedBytes = [byte[]](@($Encoding.GetPreamble()) + @($Encoding.GetBytes($Expected)))

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) |
            Should -BeExactly ([Convert]::ToBase64String($ExpectedBytes))

        $SecondOutput = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false -ErrorAction Stop)

        $Second = $SecondOutput | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Second.Proposal.Status | Should -Be 'NoChanges'
        $Second.Proposal.AcceptedCorrections | Should -HaveCount 0
        $Second.Application.Status | Should -Be 'NotAttempted'
        $Second.Application.CommittedCorrections | Should -HaveCount 0
        $Second.Report.EffectiveFindings | Should -HaveCount 0
    }

    It 'uses candidate findings under WhatIf without reporting either group committed' {
        Mock Save-AstDocument -ModuleName Nitpick { throw 'WhatIf must not call Save.' }

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix -WhatIf `
            -Output Object -ErrorOn Information -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.Application.Status | Should -Be 'WhatIf'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 4

        $Result.Report.EffectiveText | Should -BeExactly $Expected
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0
        $Result.Report.EffectiveFindings | Should -HaveCount 0

        $Summary.FindingCount | Should -Be 0
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 0

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes
    }

    It 'restores original findings and thresholds when the real transaction fails to commit' {
        Mock Invoke-AstFileReplacement -ModuleName AstEditor {
            throw [System.IO.IOException]::new('Simulated structural commit failure.')
        }

        $Errors = @()

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false `
            -ErrorAction SilentlyContinue -ErrorVariable Errors)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })

        $Result.Application.Status | Should -Be 'FailedWrite'
        $Result.Application.WriteResult.WasWritten | Should -BeFalse
        $Result.Application.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.CandidateText | Should -BeExactly $Expected
        $Result.Proposal.CandidateFindings | Should -HaveCount 0
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 4
        $Result.Proposal.SkippedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -BeExactly $Source
        $Result.Report.EffectiveFindings | Should -HaveCount 2
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0

        $Findings | Should -HaveCount 2

        $Summary.FindingCount | Should -Be 2
        $Summary.InformationCount | Should -Be 2
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 0
        $Summary.SkippedCorrectionCount | Should -Be 0
        $Summary.FailedTargetCount | Should -Be 1

        ($Errors | Out-String) | Should -Match 'Simulated structural commit failure'
        ($Errors | Out-String) | Should -Match "Encountered 2 findings at or above the 'Information' severity threshold"

        Should -Invoke Invoke-AstFileReplacement -ModuleName AstEditor -Times 1 -Exactly

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes

        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'counts diagnostic-only findings remaining after a successful coordinated fix' {
        $MixedSource = '-not ($Value -is [int]); -not ($Other -is [string] > $OutputPath)'
        $MixedExpected = ' ($Value -isnot [int]); -not ($Other -is [string] > $OutputPath)'
        [System.IO.File]::WriteAllText($Path, $MixedSource)
        $Errors = @()

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false `
            -ErrorAction SilentlyContinue -ErrorVariable Errors)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.Application.WriteResult.WasWritten | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount 2
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 1
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0].Corrections | Should -BeNullOrEmpty
        $Result.Report.EffectiveText | Should -BeExactly $MixedExpected

        $Summary.FindingCount | Should -Be 1
        $Summary.InformationCount | Should -Be 1
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 1
        $Summary.FailedTargetCount | Should -Be 0

        ($Errors | Out-String) | Should -Match "Encountered 1 findings at or above the 'Information' severity threshold"

        [System.IO.File]::ReadAllText($Path) | Should -BeExactly $MixedExpected
    }
}
