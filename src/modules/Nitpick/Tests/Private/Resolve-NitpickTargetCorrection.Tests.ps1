BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickTargetCorrection' {
    It 'returns the original findings unchanged with no CorrectionPreview when Fix is omitted' {
        $Result = InModuleScope Nitpick {
            Resolve-NitpickTargetCorrection `
                -Document ([pscustomobject]@{}) `
                -Finding @() `
                -Rule @() `
                -Ast { }.Ast `
                -Summary ([NitpickSummary]::new())
        }

        $Result.CorrectionPreview | Should -BeNullOrEmpty
        $Result.FinalFindings | Should -HaveCount 0
    }

    It 'marks an in-memory document InMemory without invoking ShouldProcess or writing' {
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Save-AstDocument must not be called for in-memory documents.' }

        $Result = InModuleScope Nitpick {
            $Document = New-AstDocument -InputObject '$Value = 1'
            $Extent = $Document.Ast.EndBlock.Statements[0].Extent
            $Correction = New-NitpickCorrection `
                -ViolationExtent $Extent `
                -ReplacementText '$Value = 2' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace value' `
                -RuleName TestRule

            $Finding = New-NitpickFinding `
                -RuleName TestRule `
                -Message 'Test finding' `
                -ViolationExtent $Extent `
                -Severity Warning `
                -RuleSuppressionID TestRule `
                -ScriptPath '<ScriptBlock>' `
                -Corrections @($Correction) `
                -Explanation 'Verifies the in-memory short-circuit.'

            Resolve-NitpickTargetCorrection `
                -Fix `
                -Document $Document `
                -Finding @($Finding) `
                -Rule @() `
                -Ast $Document.Ast `
                -Summary ([NitpickSummary]::new())
        }

        $Result.CorrectionPreview.WriteStatus | Should -Be 'InMemory'
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'commits a file-backed correction, categorizes the fixed finding, and bumps Summary counters' {
        $Path = Join-Path $TestDrive 'TargetCorrection.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')

        $Result = InModuleScope Nitpick -Parameters @{ Path = $Path } {
            param ($Path)
            $Document = New-AstDocument -Path $Path
            $Extent = $Document.Ast.EndBlock.Statements[0].Extent
            $Correction = New-NitpickCorrection `
                -ViolationExtent $Extent `
                -ReplacementText '$Value = 2' `
                -FilePathOrContext $Path `
                -Description 'Replace value' `
                -RuleName TestRule

            $Finding = New-NitpickFinding `
                -RuleName TestRule `
                -Message 'Test finding' `
                -ViolationExtent $Extent `
                -Severity Warning `
                -RuleSuppressionID TestRule `
                -ScriptPath $Path `
                -Corrections @($Correction) `
                -Explanation 'Verifies the committed-write path.'

            $Summary = [NitpickSummary]::new()

            $Result = Resolve-NitpickTargetCorrection `
                -Fix `
                -Document $Document `
                -Finding @($Finding) `
                -Rule @() `
                -Ast $Document.Ast `
                -Summary $Summary `
                -Confirm:$false

            [pscustomobject]@{
                Result = $Result
                Summary = $Summary
            }
        }

        $Result.Result.CorrectionPreview.WriteStatus | Should -Be 'Written'
        $Result.Result.CorrectionPreview.Findings.Fixed | Should -HaveCount 1
        # No Rule was supplied for reanalysis, so WasReanalyzed stays false and FinalFindings
        # still reflects the pre-fix finding set; Start-Nitpicking always passes real Rule.
        $Result.Result.FinalFindings | Should -HaveCount 1
        $Result.Summary.FixedFindingCount | Should -Be 1
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 2'
    }
}
