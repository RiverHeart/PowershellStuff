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
            -RuleName 'SecondAssignment'

        $Correction.HasOffsets | Should -BeTrue
        $Correction.StartOffset | Should -Be $Extent.StartOffset
        $Correction.EndOffset | Should -Be $Extent.EndOffset
        $Correction.ExpectedText | Should -Be '$Second = 2'
        $Correction.Applicability | Should -Be 'Safe'
        $Correction.RuleName | Should -Be 'SecondAssignment'
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

    It 'accepts or skips every correction in a change set together' {
        $Source = '$First = 1; $Second = 2; $Third = 3'
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $FirstExtent = $Ast.EndBlock.Statements[0].Extent
        $SecondExtent = $Ast.EndBlock.Statements[1].Extent
        $ThirdExtent = $Ast.EndBlock.Statements[2].Extent
        $Corrections = @(
            New-NitpickCorrection `
                -ViolationExtent $FirstExtent `
                -ReplacementText '$First = 2' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the first assignment.' `
                -ChangeSetId 'CoupledAssignments'
            New-NitpickCorrection `
                -StartLineNumber $SecondExtent.StartLineNumber `
                -EndLineNumber $SecondExtent.EndLineNumber `
                -StartColumnNumber $SecondExtent.StartColumnNumber `
                -EndColumnNumber $SecondExtent.EndColumnNumber `
                -StartOffset $SecondExtent.StartOffset `
                -EndOffset $SecondExtent.EndOffset `
                -ExpectedText '$Second = 9' `
                -ReplacementText '$Second = 3' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the second assignment.' `
                -ChangeSetId 'CoupledAssignments'
            New-NitpickCorrection `
                -ViolationExtent $ThirdExtent `
                -ReplacementText '$Third = 4' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the third assignment.'
        )
        $Finding = New-NitpickFinding `
            -RuleName 'ReplaceAssignments' `
            -Message 'Replace assignments.' `
            -ViolationExtent $FirstExtent `
            -Severity Information `
            -RuleSuppressionID 'ReplaceAssignments' `
            -Corrections $Corrections `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises all-or-nothing correction change sets.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding

        $Result.RenderedText | Should -Be $Source
        $Result.Corrections.Accepted | Should -HaveCount 0
        $Result.Corrections.Skipped | Should -HaveCount 3
        $Result.Corrections.Skipped.Reason | Should -Contain 'AstEditor rejected the target because an edit is stale.'
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
        $Finding = New-NitpickFinding `
            -RuleName 'ReplaceAssignments' `
            -Message 'Replace assignments.' `
            -ViolationExtent $FirstExtent `
            -Severity Information `
            -RuleSuppressionID 'ReplaceAssignments' `
            -Corrections $Corrections `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises independent corrections.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding

        $Result.RenderedText | Should -Be '$First = 100; $Second = 200'
        $Result.Corrections.Accepted | Should -HaveCount 2
        $Result.Corrections.Skipped | Should -HaveCount 0
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
                -RuleName 'RenameVariable'
            New-NitpickCorrection `
                -ViolationExtent $Extent `
                -ReplacementText '$Value = 456' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace the assignment.' `
                -RuleName 'ReplaceAssignment'
        )
        $Finding = New-NitpickFinding `
            -RuleName 'OverlappingRules' `
            -Message 'Exercise overlapping corrections.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID 'OverlappingRules' `
            -Corrections $Corrections `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises target-level conflict rejection.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding

        $Result.RenderedText | Should -Be $Source
        $Result.Corrections.Accepted | Should -HaveCount 0
        $Result.Corrections.Skipped | Should -HaveCount 2
        $Result.Corrections.Conflicts | Should -HaveCount 1
        $Result.Corrections.Conflicts[0].ExistingCorrection.RuleName | Should -Be 'RenameVariable'
        $Result.Corrections.Conflicts[0].IncomingCorrection.RuleName | Should -Be 'ReplaceAssignment'
    }

    It 'keeps preview mode from changing file-backed targets' {
        $Path = Join-Path $TestDrive 'Preview.ps1'
        $Source = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        [System.IO.File]::WriteAllText($Path, $Source)

        $Results = @(
            Start-Nitpicking `
                -Path $Path `
                -IncludeRule AvoidParameterAttributeBool `
                -Fix `
                -Preview `
                -Output Object `
                -NoSummary
        )
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        }

        $Preview.Path | Should -Be (Resolve-Path -LiteralPath $Path).Path
        $Preview.RenderedText | Should -Be 'param([Parameter(Mandatory)] [string] $Name)'
        [System.IO.File]::ReadAllText($Path) | Should -Be $Source
        $Preview.WasWritten | Should -BeFalse
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
            -RuleName 'ReplaceAssignment'
        $Finding = New-NitpickFinding `
            -RuleName 'ReplaceAssignment' `
            -Message 'Replace the assignment.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID 'ReplaceAssignment' `
            -Corrections $Correction `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises in-memory correction preview.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding

        $Result.RenderedText | Should -Be '$Value = 2'
        $Result.Corrections.Accepted | Should -HaveCount 1
        $Result.WasWritten | Should -BeFalse
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
                    -RuleName 'ReplaceValue'

                New-NitpickFinding `
                    -RuleName 'ReplaceValue' `
                    -Message 'Replace the value.' `
                    -ViolationExtent $Assignment.Extent `
                    -Severity Information `
                    -RuleSuppressionID 'ReplaceValue' `
                    -Corrections $Correction `
                    -ScriptPath '<ScriptBlock>' `
                    -Explanation 'Exercises final reanalysis.' `
                    -OutputAs NitpickFinding
            }
        $InitialFindings = @($Rule.Invoke($Ast))

        $Result = Resolve-NitpickCorrection `
            -Script $Source `
            -Finding $InitialFindings `
            -Rule $Rule

        $InitialFindings | Should -HaveCount 1
        $Result.RenderedText | Should -Be '$Value = 2'
        $Result.Findings.Original | Should -HaveCount 1
        $Result.Findings.Final | Should -HaveCount 0
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
            -RuleName 'InvalidReplacement'

        $Finding = New-NitpickFinding `
            -RuleName 'InvalidReplacement' `
            -Message 'Exercise parse validation.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID 'InvalidReplacement' `
            -Corrections $Correction `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises rejected candidate text.' `
            -OutputAs NitpickFinding

        $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding

        $Result.RenderedText | Should -Be $Source
        $Result.CandidateText | Should -Be 'if ('
        $Result.Corrections.Accepted | Should -HaveCount 0
        $Result.Corrections.Skipped | Should -HaveCount 1
        $Result.ParseErrors | Should -Not -BeNullOrEmpty
        $Result.WasWritten | Should -BeFalse
    }

    It 'reports findings and severity counts from final analysis after fixing' {
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
                        -RuleName 'FinalSeverityRule'
                )
            } elseif ($Assignment.Extent.Text -eq '$Value = 2') {
                $Severity = 'Warning'
            } else {
                return
            }

            $FindingParameters = @{
                RuleName = 'FinalSeverityRule'
                Message = 'Final analysis finding.'
                ViolationExtent = $Assignment.Extent
                Severity = $Severity
                RuleSuppressionID = 'FinalSeverityRule'
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
                -IncludeRule FinalSeverityRule `
                -Fix `
                -ErrorOn Error `
                -Output Object `
                -ErrorAction SilentlyContinue `
                -ErrorVariable Errors
        )
        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Findings | Should -HaveCount 1
        $Findings[0].Severity | Should -Be 'Warning'
        $Preview.Findings.Final | Should -HaveCount 1
        $Preview.Findings.Final[0].Severity | Should -Be 'Warning'
        $Preview.Corrections.Accepted | Should -HaveCount 1
        $Summary.FindingCount | Should -Be 1
        $Summary.ErrorCount | Should -Be 0
        $Summary.WarningCount | Should -Be 1
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

            $Corrections = if ($Assignment.Extent.Text -eq '$Value = 123') {
                @(
                    New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText '$Value = 456' `
                        -FilePathOrContext $Assignment.Extent.File `
                        -Description 'First conflicting replacement.' `
                        -RuleName 'PerTargetRule'
                    New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText '$Value = 789' `
                        -FilePathOrContext $Assignment.Extent.File `
                        -Description 'Second conflicting replacement.' `
                        -RuleName 'PerTargetRule'
                )
            } elseif ($Assignment.Extent.Text -eq '$Value = 1') {
                @(
                    New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText '$Value = 2' `
                        -FilePathOrContext $Assignment.Extent.File `
                        -Description 'Valid replacement.' `
                        -RuleName 'PerTargetRule'
                )
            } else {
                return
            }

            New-NitpickFinding `
                -RuleName 'PerTargetRule' `
                -Message 'Per-target correction test.' `
                -ViolationExtent $Assignment.Extent `
                -Severity Information `
                -RuleSuppressionID 'PerTargetRule' `
                -Corrections $Corrections `
                -ScriptPath $Assignment.Extent.File `
                -Explanation 'Verifies target preview failure isolation.' `
                -OutputAs NitpickFinding
        }
        Register-Nitpick -Callable $Rule -Name PerTargetRule -Source Tests

        $Results = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludeRule PerTargetRule `
                -Fix `
                -Output Object `
                -NoSummary
        )
        $Previews = @($Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        })
        $ConflictPreview = $Previews | Where-Object Path -eq $ConflictPath
        $ValidPreview = $Previews | Where-Object Path -eq $ValidPath

        $ConflictPreview.Corrections.Accepted | Should -HaveCount 0
        $ConflictPreview.Corrections.Skipped | Should -HaveCount 2
        $ConflictPreview.Corrections.Conflicts | Should -HaveCount 1
        $ConflictPreview.RenderedText | Should -Be $ConflictSource
        $ValidPreview.Corrections.Accepted | Should -HaveCount 1
        $ValidPreview.Corrections.Skipped | Should -HaveCount 0
        $ValidPreview.RenderedText | Should -Be '$Value = 2'
        [System.IO.File]::ReadAllText($ConflictPath) | Should -Be $ConflictSource
        $ValidPreview.WasWritten | Should -BeTrue
        $ValidPreview.WriteStatus | Should -Be 'Written'
        [System.IO.File]::ReadAllText($ValidPath) | Should -Be '$Value = 2'
    }
}
