BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking coordinated structural transactions' {
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

        $Results = @(Start-Nitpicking -Script $Ast -IncludeRule UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.WriteStatus | Should -Be 'InMemory'
        $Result.Document.IsFileBacked | Should -BeFalse
        $Result.WasWritten | Should -BeFalse
        $Result.WasReanalyzed | Should -BeTrue
        $Result.RenderedText | Should -BeExactly $Expected
        $Result.CandidateText | Should -BeExactly $Expected
        $Result.Corrections.Accepted | Should -HaveCount 4
        $Result.Corrections.Fixed | Should -HaveCount 0
        $Result.Findings.Original | Should -HaveCount 2
        $Result.Findings.Final | Should -HaveCount 0
        $Summary.FindingCount | Should -Be 0
        $Summary.FixedFindingCount | Should -Be 0
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes
    }

    It 'previews and commits equivalent groups with final counts and preserved bytes' {
        $PreviewOutput = @(Start-Nitpicking -Path $Path -IncludeRule UseIsNotOperator -Fix -Preview `
            -Output Object -ErrorOn Information -ErrorAction Stop)
        $Preview = $PreviewOutput | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $PreviewSummary = $PreviewOutput | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Preview.WriteStatus | Should -Be 'Preview'
        $Preview.WasWritten | Should -BeFalse
        $Preview.RenderedText | Should -BeExactly $Expected
        $Preview.Corrections.Accepted | Should -HaveCount 4
        $Preview.Corrections.Fixed | Should -HaveCount 0
        $Preview.Findings.Fixed | Should -HaveCount 0
        $PreviewSummary.FindingCount | Should -Be 0
        $PreviewSummary.FixedFindingCount | Should -Be 0
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes

        $ApplyOutput = @(Start-Nitpicking -Path $Path -IncludeRule UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false -ErrorAction Stop)
        $Applied = $ApplyOutput | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $ApplyOutput | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Applied.WriteStatus | Should -Be 'Written'
        $Applied.WriteResult.WasWritten | Should -BeTrue
        $Applied.WasWritten | Should -BeTrue
        $Applied.WasReanalyzed | Should -BeTrue
        $Applied.OriginalFingerprint | Should -BeExactly $Preview.OriginalFingerprint
        $Applied.Diff | Should -BeExactly $Preview.Diff
        $Applied.CandidateText | Should -BeExactly $Preview.CandidateText
        $Applied.RenderedText | Should -BeExactly $Expected
        $Applied.Corrections.Accepted | Should -HaveCount 4
        for ($Index = 0; $Index -lt 4; $Index++) {
            foreach ($Property in @('StartOffset', 'EndOffset', 'ExpectedText', 'ReplacementText', 'ChangeSetId', 'RuleName')) {
                $Applied.Corrections.Accepted[$Index].$Property |
                    Should -BeExactly $Preview.Corrections.Accepted[$Index].$Property
            }
        }
        $Applied.Corrections.Fixed | Should -HaveCount 4
        $Applied.Findings.Fixed | Should -HaveCount 2
        $Applied.Findings.Remaining | Should -HaveCount 0
        $Applied.Findings.Final | Should -HaveCount 0
        $Summary.TargetCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        $Summary.InformationCount | Should -Be 0
        $Summary.WarningCount | Should -Be 0
        $Summary.ErrorCount | Should -Be 0
        $Summary.FixedFindingCount | Should -Be 2
        $Summary.SkippedCorrectionCount | Should -Be 0
        $Summary.FailedTargetCount | Should -Be 0
        $ExpectedBytes = [byte[]](@($Encoding.GetPreamble()) + @($Encoding.GetBytes($Expected)))
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) |
            Should -BeExactly ([Convert]::ToBase64String($ExpectedBytes))

        $SecondOutput = @(Start-Nitpicking -Path $Path -IncludeRule UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false -ErrorAction Stop)
        $Second = $SecondOutput | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Second.WriteStatus | Should -Be 'NoChanges'
        $Second.WasWritten | Should -BeFalse
        $Second.Corrections.Accepted | Should -HaveCount 0
        $Second.Findings.Final | Should -HaveCount 0
    }

    It 'uses candidate findings under WhatIf without reporting either group committed' {
        Mock Save-AstDocument -ModuleName Nitpick { throw 'WhatIf must not call Save.' }

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule UseIsNotOperator -Fix -WhatIf `
            -Output Object -ErrorOn Information -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.WriteStatus | Should -Be 'WhatIf'
        $Result.WasWritten | Should -BeFalse
        $Result.WasReanalyzed | Should -BeTrue
        $Result.RenderedText | Should -BeExactly $Expected
        $Result.Corrections.Accepted | Should -HaveCount 4
        $Result.Corrections.Fixed | Should -HaveCount 0
        $Result.Findings.Fixed | Should -HaveCount 0
        $Result.Findings.Final | Should -HaveCount 0
        $Summary.FindingCount | Should -Be 0
        $Summary.FixedFindingCount | Should -Be 0
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -BeExactly $OriginalBytes
    }

    It 'restores original findings and thresholds when the real transaction fails to commit' {
        Mock Invoke-AstFileReplacement -ModuleName AstEditor {
            throw [System.IO.IOException]::new('Simulated structural commit failure.')
        }
        $Errors = @()

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false `
            -ErrorAction SilentlyContinue -ErrorVariable Errors)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })

        $Result.WriteStatus | Should -Be 'FailedWrite'
        $Result.WasWritten | Should -BeFalse
        $Result.WasReanalyzed | Should -BeFalse
        $Result.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.CandidateText | Should -BeExactly $Expected
        $Result.Findings.Candidate | Should -HaveCount 0
        $Result.RenderedText | Should -BeExactly $Source
        $Result.Findings.Final | Should -HaveCount 2
        $Result.Findings.Remaining | Should -HaveCount 2
        $Result.Findings.Fixed | Should -HaveCount 0
        $Result.Findings.Skipped | Should -HaveCount 2
        $Result.Corrections.Accepted | Should -HaveCount 4
        $Result.Corrections.Fixed | Should -HaveCount 0
        $Result.Corrections.Skipped | Should -HaveCount 4
        foreach ($Skipped in $Result.Corrections.Skipped) {
            $Skipped.Reason | Should -BeLike 'Commit failed (FailedWrite):*'
        }
        $Findings | Should -HaveCount 2
        $Summary.FindingCount | Should -Be 2
        $Summary.InformationCount | Should -Be 2
        $Summary.FixedFindingCount | Should -Be 0
        $Summary.SkippedCorrectionCount | Should -Be 4
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

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule UseIsNotOperator -Fix `
            -Output Object -ErrorOn Information -Confirm:$false `
            -ErrorAction SilentlyContinue -ErrorVariable Errors)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.WasWritten | Should -BeTrue
        $Result.Corrections.Fixed | Should -HaveCount 2
        $Result.Findings.Fixed | Should -HaveCount 1
        $Result.Findings.Remaining | Should -HaveCount 1
        $Result.Findings.Remaining[0].Corrections | Should -BeNullOrEmpty
        $Result.RenderedText | Should -BeExactly $MixedExpected
        $Summary.FindingCount | Should -Be 1
        $Summary.InformationCount | Should -Be 1
        $Summary.FixedFindingCount | Should -Be 1
        $Summary.FailedTargetCount | Should -Be 0
        ($Errors | Out-String) | Should -Match "Encountered 1 findings at or above the 'Information' severity threshold"
        [System.IO.File]::ReadAllText($Path) | Should -BeExactly $MixedExpected
    }
}
