using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Nitpick autocorrection contracts' -Tag 'AutocorrectionContract' {
    It 'preserves one-based line and column coordinates for ScriptAnalyzer' {
        $Source = "`$First = 1`n`$Second = 2"
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Extent = $Ast.EndBlock.Statements[1].Extent

        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Second = 3' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the second assignment.'

        $Correction.StartLineNumber | Should -Be 2
        $Correction.StartColumnNumber | Should -Be 1
        $Correction.EndLineNumber | Should -Be 2
        $Correction.EndColumnNumber | Should -Be 12
    }

    It 'converts native coordinates and replacement text without changing them' {
        $Correction = New-NitpickCorrection `
            -StartLineNumber 2 `
            -EndLineNumber 3 `
            -StartColumnNumber 4 `
            -EndColumnNumber 5 `
            -ReplacementText "first`nsecond" `
            -FilePathOrContext 'Example.ps1' `
            -Description 'Replace a multiline range.' `
            -OutputAs CorrectionExtent

        $Correction.StartLineNumber | Should -Be 2
        $Correction.EndLineNumber | Should -Be 3
        $Correction.StartColumnNumber | Should -Be 4
        $Correction.EndColumnNumber | Should -Be 5
        $Correction.Text | Should -Be "first`nsecond"
        $Correction.File | Should -Be 'Example.ps1'
    }

    It 'keeps file-backed and in-memory correction provenance explicit' {
        $Path = Join-Path $TestDrive 'Source.ps1'
        Set-Content -LiteralPath $Path -Value '$Value = 1' -NoNewline
        $FileAst = Import-ScriptBlockAst -FilePath $Path
        $FileExtent = $FileAst.EndBlock.Statements[0].Extent
        $MemoryExtent = { $Value = 1 }.Ast.EndBlock.Statements[0].Extent

        $FileCorrection = New-NitpickCorrection `
            -ViolationExtent $FileExtent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext $FileExtent.File `
            -Description 'Replace a file-backed assignment.'
        $MemoryCorrection = New-NitpickCorrection `
            -ViolationExtent $MemoryExtent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace an in-memory assignment.'

        $FileCorrection.FilePathOrContext | Should -Be (Resolve-Path -LiteralPath $Path).Path
        $MemoryCorrection.FilePathOrContext | Should -Be '<ScriptBlock>'
    }

    It 'does not expose file mutation on an individual correction' {
        $Extent = { $Value = 1 }.Ast.EndBlock.Statements[0].Extent
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the assignment.'

        $Correction.PSObject.Methods.Name | Should -Not -Contain 'Fix'
    }

    It 'captures zero-based half-open offsets and expected text from an extent' {
        $Source = '$First = 1; $Second = 2'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Extent = $Ast.EndBlock.Statements[1].Extent

        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Second = 3' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the second assignment.' `
            -RuleId 'Local/SecondAssignment'

        $Correction.TextEdits[0].StartOffset | Should -Be $Extent.StartOffset
        $Correction.TextEdits[0].EndOffset | Should -Be $Extent.EndOffset
        $Correction.TextEdits[0].ExpectedText | Should -Be '$Second = 2'
        $Correction.Applicability | Should -Be 'Safe'
        $Correction.RuleId | Should -Be 'Local/SecondAssignment'
    }

    It 'classifies corrections as Safe, Review, or Unsafe' -ForEach @(
        @{ Applicability = 'Safe' }
        @{ Applicability = 'Review' }
        @{ Applicability = 'Unsafe' }
    ) {
        $Extent = { $Value }.Ast.EndBlock.Statements[0].Extent

        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.' `
            -Applicability $Applicability

        $Correction.Applicability | Should -Be $Applicability
    }

    It 'accepts or skips every edit of a correction together' {
        $Source = '$First = 1; $Second = 2; $Third = 3'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $FirstExtent = $Ast.EndBlock.Statements[0].Extent
        $SecondExtent = $Ast.EndBlock.Statements[1].Extent
        $ThirdExtent = $Ast.EndBlock.Statements[2].Extent

        # One fix whose second edit is stale: both edits must be skipped together.
        $CoupledCorrection = New-NitpickCorrection `
            -TextEdit @(
                New-AstTextEdit `
                    -Extent $FirstExtent `
                    -ReplacementText '$First = 2' `
                    -Reason 'Replace the coupled assignments.'
                New-AstTextEdit `
                    -StartLineNumber $SecondExtent.StartLineNumber `
                    -EndLineNumber $SecondExtent.EndLineNumber `
                    -StartColumnNumber $SecondExtent.StartColumnNumber `
                    -EndColumnNumber $SecondExtent.EndColumnNumber `
                    -StartOffset $SecondExtent.StartOffset `
                    -EndOffset $SecondExtent.EndOffset `
                    -ExpectedText '$Second = 9' `
                    -ReplacementText '$Second = 3' `
                    -Reason 'Replace the coupled assignments.'
            ) `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the coupled assignments.'

        $IndependentCorrection = New-NitpickCorrection `
            -ViolationExtent $ThirdExtent `
            -ReplacementText '$Third = 4' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the third assignment.'

        $Findings = @(
            New-NitpickFinding `
                -RuleId 'Local/ReplaceAssignments' `
                -Message 'Replace coupled assignments.' `
                -ViolationExtent $FirstExtent `
                -Severity Information `
                -Corrections $CoupledCorrection `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Exercises all-or-nothing correction edits.' `
                -OutputAs NitpickFinding
            New-NitpickFinding `
                -RuleId 'Local/ReplaceAssignments' `
                -Message 'Replace the third assignment.' `
                -ViolationExtent $ThirdExtent `
                -Severity Information `
                -Corrections $IndependentCorrection `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Exercises all-or-nothing correction edits.' `
                -OutputAs NitpickFinding
        )

        $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Findings

        $Result.CandidateText | Should -Be $Source
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections.Reason | Should -Contain 'AstEditor rejected the target because an edit is stale.'
    }

    It 'previews independent corrections in one render pass' {
        $Source = '$First = 1; $Second = 2'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $FirstExtent = $Ast.EndBlock.Statements[0].Extent
        $SecondExtent = $Ast.EndBlock.Statements[1].Extent
        $Corrections = @(
            New-NitpickCorrection `
                -ViolationExtent $FirstExtent `
                -ReplacementText '$First = 100' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the first assignment.'

            New-NitpickCorrection `
                -ViolationExtent $SecondExtent `
                -ReplacementText '$Second = 200' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the second assignment.'
        )
        # Independent fixes belong to independent findings; a single finding
        # offering several Safe corrections is skipped as ambiguous.
        $Findings = @(
            New-NitpickFinding `
                -RuleId 'Local/ReplaceAssignments' `
                -Message 'Replace the first assignment.' `
                -ViolationExtent $FirstExtent `
                -Severity Information `
                -Corrections $Corrections[0] `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Exercises independent corrections.' `
                -OutputAs NitpickFinding
            New-NitpickFinding `
                -RuleId 'Local/ReplaceAssignments' `
                -Message 'Replace the second assignment.' `
                -ViolationExtent $SecondExtent `
                -Severity Information `
                -Corrections $Corrections[1] `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Exercises independent corrections.' `
                -OutputAs NitpickFinding
        )

        $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Findings

        $Result.CandidateText | Should -Be '$First = 100; $Second = 200'
        $Result.AcceptedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections | Should -HaveCount 0
    }

    It 'rejects the complete target batch when independent change sets overlap' {
        $Source = '$Value = 123'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Extent = $Ast.EndBlock.Statements[0].Extent
        $Corrections = @(
            New-NitpickCorrection `
                -StartLineNumber 1 `
                -EndLineNumber 1 `
                -StartColumnNumber 1 `
                -EndColumnNumber 7 `
                -StartOffset 0 `
                -EndOffset 6 `
                -ExpectedText '$Value' `
                -ReplacementText '$First' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Rename the variable.' `
                -RuleId 'Local/RenameVariable'

            New-NitpickCorrection `
                -ViolationExtent $Extent `
                -ReplacementText '$Value = 456' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the assignment.' `
                -RuleId 'Local/ReplaceAssignment'
        )
        $Finding = New-NitpickFinding `
            -RuleId 'Local/OverlappingRules' `
            -Message 'Exercise overlapping corrections.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -Corrections $Corrections[0] `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises target-level conflict rejection.' `
            -OutputAs NitpickFinding
        # Overlapping fixes must come from separate findings to reach the
        # conflict policy; alternatives on one finding are skipped earlier.
        $CompetingFinding = New-NitpickFinding `
            -RuleId 'Local/OverlappingRules' `
            -Message 'Exercise overlapping corrections.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -Corrections $Corrections[1] `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises target-level conflict rejection.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding @($Finding, $CompetingFinding)

        $Result.CandidateText | Should -Be $Source
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.Conflicts | Should -HaveCount 1
        $Result.Conflicts[0].ExistingCorrection.RuleId | Should -Be 'Local/RenameVariable'
        $Result.Conflicts[0].IncomingCorrection.RuleId | Should -Be 'Local/ReplaceAssignment'
    }

    It 'keeps preview mode from changing file-backed targets' {
        $Path = Join-Path $TestDrive 'Preview.ps1'
        $Source = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        [System.IO.File]::WriteAllText($Path, $Source)

        $Results = @(
            Start-Nitpicking `
                -Path $Path `
                -IncludeRule Nitpick/AvoidParameterAttributeBool `
                -FixMode Preview `
                -Output Object `
                -NoSummary
        )
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'NitpickCorrectionResult'
        }

        $Preview.Path | Should -Be (Resolve-Path -LiteralPath $Path).Path
        $Preview.Report.EffectiveText | Should -Be 'param([Parameter(Mandatory)] [string] $Name)'
        [System.IO.File]::ReadAllText($Path) | Should -Be $Source
        $Preview.Application.Status | Should -Be 'Preview'
        $Preview.Application.AppliedCorrections | Should -HaveCount 0
    }

    It 'returns rendered text instead of writing for in-memory targets' {
        $Source = '$Value = 1'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Extent = $Ast.EndBlock.Statements[0].Extent
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the assignment.' `
            -RuleId 'Local/ReplaceAssignment'

        $Finding = New-NitpickFinding `
            -RuleId 'Local/ReplaceAssignment' `
            -Message 'Replace the assignment.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -Corrections $Correction `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises in-memory correction preview.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Finding

        $Result.CandidateText | Should -Be '$Value = 2'
        $Result.AcceptedCorrections | Should -HaveCount 1
        $Result.Status | Should -Be 'Ready'
    }

    It 'reruns selected rules against valid rendered text' {
        $Source = '$Value = 1'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Rule = New-Nitpick `
            -Name 'ReplaceValue' `
            -Source 'AutocorrectionContract' `
            -Callable {
                param ([ScriptBlockAst] $ScriptBlockAst)

                $Assignment = $ScriptBlockAst.EndBlock.Statements | Select-Object -First 1
                if ($null -eq $Assignment -or $Assignment.Extent.Text -ne '$Value = 1') {
                    return
                }

                $Correction = New-NitpickCorrection `
                    -ViolationExtent $Assignment.Extent `
                    -ReplacementText '$Value = 2' `
                    -FilePathOrContext '<ScriptBlock>' `
                    -Description 'Replace the value.' `
                    -RuleId 'Local/ReplaceValue'

                New-NitpickFinding `
                    -RuleId 'Local/ReplaceValue' `
                    -Message 'Replace the value.' `
                    -ViolationExtent $Assignment.Extent `
                    -Severity Information `
                    -Corrections $Correction `
                    -ScriptPath '<ScriptBlock>' `
                    -Explanation 'Exercises final reanalysis.' `
                    -OutputAs NitpickFinding
            }

        $InitialFindings = @($Rule.Invoke($Ast))

        $Result = Resolve-NitpickCorrectionProposal `
            -Script $Source `
            -Finding $InitialFindings `
            -Rule $Rule

        $InitialFindings | Should -HaveCount 1
        $Result.CandidateText | Should -Be '$Value = 2'
        $Result.OriginalFindings | Should -HaveCount 1
        $Result.CandidateFindings | Should -HaveCount 0
        $Result.WasReanalyzed | Should -BeTrue
    }

    It 'rejects candidate text that introduces parse errors' {
        $Source = '$Value = 1'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Extent = $Ast.EndBlock.Statements[0].Extent

        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText 'if (' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Introduce invalid syntax for validation.' `
            -RuleId 'Local/InvalidReplacement'

        $Finding = New-NitpickFinding `
            -RuleId 'Local/InvalidReplacement' `
            -Message 'Exercise parse validation.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -Corrections $Correction `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises rejected candidate text.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Finding

        $Result.OriginalText | Should -Be $Source
        $Result.CandidateText | Should -Be 'if ('
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 1
        $Result.ParseErrors | Should -Not -BeNullOrEmpty
        $Result.Status | Should -Be 'FailedValidation'
    }

    It 'reports effective findings while counting detected severities after fixing' {
        $Rule = {
            param([ScriptBlockAst] $ScriptBlockAst)

            $Assignment = $ScriptBlockAst.EndBlock.Statements | Select-Object -First 1
            if ($null -eq $Assignment) {
                return
            }

            $Corrections = @()
            if ($Assignment.Extent.Text -eq '$Value = 1') {
                $Severity = 'Error'
                $Corrections = @(
                    New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText '$Value = 2' `
                        -FilePathOrContext '<ScriptBlock>' `
                        -Description 'Replace the value.' `
                        -RuleId 'Local/FinalSeverityRule'
                )
            } elseif ($Assignment.Extent.Text -eq '$Value = 2') {
                $Severity = 'Warning'
            } else {
                return
            }

            $FindingParameters = @{
                RuleId = 'Local/FinalSeverityRule'
                Message = 'Final analysis finding.'
                ViolationExtent = $Assignment.Extent
                Severity = $Severity
                ScriptPath = '<ScriptBlock>'
                Explanation = 'Verifies final analysis severity counts.'
                OutputAs = 'NitpickFinding'
            }
            if ($Corrections.Count -gt 0) {
                $FindingParameters.Corrections = $Corrections
            }
            New-NitpickFinding @FindingParameters
        }

        Register-Nitpick -Callable $Rule -Name FinalSeverityRule -Source Tests
        $Errors = @()

        $Results = @(
            Start-Nitpicking `
                -Script '$Value = 1' `
                -IncludeRule Local/FinalSeverityRule `
                -FixMode Apply `
                -ErrorOn Error `
                -Output Object `
                -ErrorAction SilentlyContinue `
                -ErrorVariable Errors
        )

        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'NitpickCorrectionResult'
        }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Findings | Should -HaveCount 1
        $Findings[0].Severity | Should -Be 'Warning'
        $Preview.Report.EffectiveFindings | Should -HaveCount 1
        $Preview.Report.EffectiveFindings[0].Severity | Should -Be 'Warning'
        $Preview.Proposal.AcceptedCorrections | Should -HaveCount 1
        $Summary.FindingCount | Should -Be 1
        $Summary.ErrorCount | Should -Be 1
        $Summary.WarningCount | Should -Be 0
        $Summary.CorrectedFindingCount | Should -Be 1
        $Summary.UnresolvedFindingCount | Should -Be 1
        $Errors | Should -BeNullOrEmpty
    }

    It 'isolates a failed target without partially applying other target transactions' {
        $ConflictPath = Join-Path $TestDrive 'Conflict.ps1'
        $ValidPath = Join-Path $TestDrive 'Valid.ps1'
        $ConflictSource = '$Value = 123'
        $ValidSource = '$Value = 1'
        [System.IO.File]::WriteAllText($ConflictPath, $ConflictSource)
        [System.IO.File]::WriteAllText($ValidPath, $ValidSource)

        $Rule = {
            param([ScriptBlockAst] $ScriptBlockAst)

            $Assignment = $ScriptBlockAst.EndBlock.Statements | Select-Object -First 1
            if ($null -eq $Assignment) {
                return
            }

            if ($Assignment.Extent.Text -eq '$Value = 123') {
                # Conflicting fixes must come from separate findings; two Safe
                # corrections on one finding are skipped as ambiguous alternatives.
                foreach ($Replacement in '$Value = 456', '$Value = 789') {
                    $Correction = New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText $Replacement `
                        -FilePathOrContext $Assignment.Extent.File `
                        -Description "Replace the assignment with $Replacement." `
                        -RuleId 'Local/PerTargetRule'

                    New-NitpickFinding `
                        -RuleId 'Local/PerTargetRule' `
                        -Message 'Per-target correction test.' `
                        -ViolationExtent $Assignment.Extent `
                        -Severity Information `
                        -Corrections $Correction `
                        -ScriptPath $Assignment.Extent.File `
                        -Explanation 'Verifies target preview failure isolation.' `
                        -OutputAs NitpickFinding
                }
                return
            }

            $Corrections = if ($Assignment.Extent.Text -eq '$Value = 1') {
                @(
                    New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText '$Value = 2' `
                        -FilePathOrContext $Assignment.Extent.File `
                        -Description 'Valid replacement.' `
                        -RuleId 'Local/PerTargetRule'
                )
            } else {
                return
            }

            New-NitpickFinding `
                -RuleId 'Local/PerTargetRule' `
                -Message 'Per-target correction test.' `
                -ViolationExtent $Assignment.Extent `
                -Severity Information `
                -Corrections $Corrections `
                -ScriptPath $Assignment.Extent.File `
                -Explanation 'Verifies target preview failure isolation.' `
                -OutputAs NitpickFinding
        }

        Register-Nitpick -Callable $Rule -Name PerTargetRule -Source Tests

        $Results = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludePath $ConflictPath, $ValidPath `
                -IncludeRule Local/PerTargetRule `
                -FixMode Apply `
                -Output Object
        )

        $Previews = @($Results | Where-Object {
            $_.PSTypeNames -contains 'NitpickCorrectionResult'
        })

        $ValidPreview = $Previews | Where-Object Path -eq $ValidPath
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        [System.IO.File]::ReadAllText($ConflictPath) | Should -Be $ConflictSource
        [System.IO.File]::ReadAllText($ValidPath) | Should -Be '$Value = 2'

        $ConflictPreview = $Previews | Where-Object Path -eq $ConflictPath
        $ConflictPreview.Proposal.AcceptedCorrections | Should -HaveCount 0
        $ConflictPreview.Proposal.SkippedCorrections | Should -HaveCount 2
        $ConflictPreview.Proposal.Conflicts | Should -HaveCount 1
        $ConflictPreview.Proposal.Status | Should -Be 'Rejected'
        $ConflictPreview.Application.Status | Should -Be 'NotAttempted'
        $ConflictPreview.Report.AnalysisSource | Should -Be 'Original'
        $ConflictPreview.Report.EffectiveText | Should -Be $ConflictSource

        $ValidPreview.Proposal.AcceptedCorrections | Should -HaveCount 1
        $ValidPreview.Proposal.SkippedCorrections | Should -HaveCount 0
        $ValidPreview.Report.EffectiveText | Should -Be '$Value = 2'
        $ValidPreview.Application.WriteResult.WasWritten | Should -BeTrue
        $ValidPreview.Application.Status | Should -Be 'Written'

        $Summary.TargetCount | Should -Be 2
        $Summary.FailedTargetCount | Should -Be 0
        $Summary.SkippedCorrectionCount | Should -Be 2
    }
}
