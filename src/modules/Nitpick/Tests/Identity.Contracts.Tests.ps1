BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\Nitpick.psd1" -Force

    <#
    .SYNOPSIS
        Creates a producer with deliberately incorrect attribution for identity contracts.
    #>
    function New-IdentityContractRule {
        param (
            [string] $Namespace = 'Local',
            [string] $Replacement = '$Value = 2',
            [string] $ChangeSetId
        )

        $Producer = {
            param ($ScriptBlockAst)
            $Assignment = $ScriptBlockAst.EndBlock.Statements[0]
            $Corrections = @(
                if ($Assignment.Extent.Text -eq '$Value = 1') {
                    New-NitpickCorrection -ViolationExtent $Assignment.Extent `
                        -ReplacementText $Replacement -FilePathOrContext '<ScriptBlock>' `
                        -Description 'Replace assignment' -RuleName WrongCorrection
                }
            )
            foreach ($Correction in $Corrections) {
                $Correction.RuleId = 'WrongOwner/WrongCorrection'
                $Correction.ChangeSetId = $ChangeSetId
            }
            $Finding = New-NitpickFinding -RuleName WrongFinding -RuleSuppressionID WrongSuppression `
                -Message 'Assignment finding' -Severity Information -ViolationExtent $Assignment.Extent `
                -ScriptPath '<ScriptBlock>' -Explanation 'Identity contract' -Corrections $Corrections
            $Finding.RuleId = 'WrongOwner/WrongFinding'
            $Finding
        }.GetNewClosure()
        New-Nitpick -Callable $Producer -Name AssignmentStyle -Namespace $Namespace -Source Tests
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Native execution identity contracts' {
    BeforeEach {
        InModuleScope Nitpick { (Get-NitpickRegistry).Nitpicks.Clear() }
    }

    AfterEach {
        InModuleScope Nitpick { (Get-NitpickRegistry).Nitpicks.Clear() }
    }

    It 'overwrites producer attribution in both Invoke overloads without cloning results' {
        $Rule = New-IdentityContractRule -Namespace Owner
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
            '$Value = 1', [ref] $null, [ref] $null
        )
        $Standalone = @(& $Rule.Callable -ScriptBlockAst $Ast)
        $Standalone[0].RuleId | Should -Be 'WrongOwner/WrongFinding'
        $Captured = $Standalone[0]
        $Rule.Callable = { param ($ScriptBlockAst) $Captured }.GetNewClosure()

        foreach ($WithContext in $false, $true) {
            $Captured.RuleId = 'WrongOwner/WrongFinding'
            $Captured.RuleName = 'WrongFinding'
            $Captured.RuleSuppressionID = 'WrongSuppression'
            $Captured.Corrections[0].RuleId = 'WrongOwner/WrongCorrection'
            $Captured.Corrections[0].RuleName = 'WrongCorrection'
            $Correction = $Captured.Corrections[0]
            $Result = if ($WithContext) { $Rule.Invoke($Ast, @{}) } else { $Rule.Invoke($Ast) }

            [object]::ReferenceEquals($Result[0], $Captured) | Should -BeTrue
            [object]::ReferenceEquals($Result[0].Corrections[0], $Correction) | Should -BeTrue
            $Result[0].RuleId | Should -Be 'Owner/AssignmentStyle'
            $Result[0].RuleName | Should -Be AssignmentStyle
            $Result[0].RuleSuppressionID | Should -Be AssignmentStyle
            $Correction.RuleId | Should -Be 'Owner/AssignmentStyle'
            $Correction.RuleName | Should -Be AssignmentStyle
            $Correction.PSObject.Properties.Name | Should -Not -Contain RuleSuppressionID
        }
    }

    It 'retains identity in original and nonempty candidate findings under <Status>' -ForEach @(
        @{ Status = 'InMemory'; ScriptInput = $true; Preview = $false; WhatIf = $false }
        @{ Status = 'Preview'; ScriptInput = $false; Preview = $true; WhatIf = $false }
        @{ Status = 'WhatIf'; ScriptInput = $false; Preview = $false; WhatIf = $true }
        @{ Status = 'Written'; ScriptInput = $false; Preview = $false; WhatIf = $false }
    ) {
        Register-Nitpick -Callable (New-IdentityContractRule)
        $Path = Join-Path $TestDrive "$Status.ps1"
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Parameters = @{
            IncludeRule = 'Local/AssignmentStyle'; Output = 'Object'
            FixMode = if ($Preview) { 'Preview' } else { 'Apply' }
            WhatIf = $WhatIf; Confirm = $false; ErrorAction = 'Stop'
        }
        if ($ScriptInput) { $Parameters.Script = '$Value = 1' } else { $Parameters.Path = $Path }
        $Output = @(Start-Nitpicking @Parameters)
        $Result = $Output | Where-Object { $_.PSTypeNames -contains 'NitpickCorrectionResult' }

        $Result.Application.Status | Should -Be $Status
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.OriginalFindings | Should -HaveCount 1
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 1
        foreach ($Finding in @($Result.Proposal.OriginalFindings) + @($Result.Proposal.CandidateFindings) +
            @($Result.Report.EffectiveFindings) + @($Result.Report.FindingsWithCommittedCorrections)) {
            $Finding.RuleId | Should -Be 'Local/AssignmentStyle'
            $Finding.RuleName | Should -Be AssignmentStyle
            $Finding.RuleSuppressionID | Should -Be AssignmentStyle
        }
        $Result.Proposal.AcceptedCorrections[0].RuleId | Should -Be 'Local/AssignmentStyle'
        [object]::ReferenceEquals($Result.Proposal.AcceptedCorrections[0],
            $Result.Proposal.OriginalFindings[0].Corrections[0]) | Should -BeTrue
        $Result.Report.AnalysisSource | Should -Be Candidate
        if ($Status -eq 'Written') {
            $Result.Application.CommittedCorrections[0].RuleId | Should -Be 'Local/AssignmentStyle'
            [object]::ReferenceEquals($Result.Application.CommittedCorrections[0],
                $Result.Proposal.AcceptedCorrections[0]) | Should -BeTrue
            $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 1
            [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 2'
        } else {
            $Result.Application.CommittedCorrections | Should -HaveCount 0
            [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
        }
    }

    It 'qualifies conflict and verbose skip diagnostics for equal local names' {
        $Rules = @(
            New-IdentityContractRule -Namespace First
            New-IdentityContractRule -Namespace Second -Replacement '$Value = 3'
        )
        $Rules | Register-Nitpick
        $Output = @(Start-Nitpicking -Script '$Value = 1' -IncludeRule '*/AssignmentStyle' `
            -FixMode Apply -Output Object -Verbose 4>&1)
        $Result = $Output | Where-Object { $_.PSTypeNames -contains 'NitpickCorrectionResult' }
        $Result.Proposal.Status | Should -Be Rejected
        $Result.Proposal.Conflicts | Should -HaveCount 1
        $Conflict = $Result.Proposal.Conflicts[0]
        @($Conflict.ExistingCorrection.RuleId, $Conflict.IncomingCorrection.RuleId) |
            Sort-Object | Should -Be @('First/AssignmentStyle', 'Second/AssignmentStyle')
        $Conflict.Reason | Should -Match 'First/AssignmentStyle'
        $Conflict.Reason | Should -Match 'Second/AssignmentStyle'
        $VerboseText = ($Output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join "`n"
        $VerboseText | Should -Match "Skipped correction from 'First/AssignmentStyle'"
        $VerboseText | Should -Match "Skipped correction from 'Second/AssignmentStyle'"
        @($Result.Proposal.SkippedCorrections.Correction.RuleId | Sort-Object) |
            Should -Be @('First/AssignmentStyle', 'Second/AssignmentStyle')
    }

    It 'preserves intentional cross-rule change sets without prefixing their IDs' {
        $Rules = @(
            New-IdentityContractRule -Namespace First -ChangeSetId Shared
            New-IdentityContractRule -Namespace Second -ChangeSetId Shared
        )
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
            '$Value = 1', [ref] $null, [ref] $null
        )
        $Findings = @($Rules[0].Invoke($Ast)) + @($Rules[1].Invoke($Ast))
        $Findings[0].Corrections[0].Applicability = 'Review'
        $Proposal = Resolve-NitpickCorrectionProposal -Script '$Value = 1' -Finding $Findings
        $Proposal.AcceptedCorrections | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount 2
        foreach ($Skipped in $Proposal.SkippedCorrections) {
            $Skipped.Correction.ChangeSetId | Should -Be Shared
            $Skipped.Reason | Should -Be "Applicability 'Review' is not selected."
        }
    }

    It 'uses qualified labels in text, default object formatting, and string conversion' {
        foreach ($Namespace in 'First', 'Second') {
            Register-Nitpick -Callable (New-IdentityContractRule -Namespace $Namespace)
        }
        $Text = Start-Nitpicking -Script '$Value = 1' -IncludeRule '*/AssignmentStyle' -NoSummary
        $Text | Should -Match 'First/AssignmentStyle'
        $Text | Should -Match 'Second/AssignmentStyle'
        $Findings = @(Start-Nitpicking -Script '$Value = 1' -IncludeRule '*/AssignmentStyle' -Output Object -NoSummary)
        $Formatted = $Findings | Format-Table | Out-String -Width 240
        foreach ($Finding in $Findings) {
            $Formatted | Should -Match ([regex]::Escape($Finding.RuleId))
            $Finding.ToString() | Should -Match ([regex]::Escape($Finding.RuleId))
        }
    }

    It 'keeps standalone labels unqualified in display and direct resolver conflicts' {
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
            '$Value = 1', [ref] $null, [ref] $null
        )
        $Findings = @(
            foreach ($Replacement in '$Value = 2', '$Value = 3') {
                $Correction = New-NitpickCorrection -ViolationExtent $Ast.EndBlock.Statements[0].Extent `
                    -ReplacementText $Replacement -FilePathOrContext '<ScriptBlock>' -Description 'Replace' `
                    -RuleName Standalone
                New-NitpickFinding -RuleName Standalone -RuleSuppressionID Standalone `
                    -Message 'Standalone finding' -Severity Information -ViolationExtent $Ast.Extent `
                    -ScriptPath '<ScriptBlock>' -Explanation 'Standalone' -Corrections $Correction
            }
        )
        $Text = InModuleScope Nitpick -Parameters @{ Ast = $Ast; Findings = $Findings } {
            param ($Ast, $Findings)
            Format-NitpickText -Ast $Ast -Finding $Findings
        }
        $Text | Should -Match '  Standalone'
        $Text | Should -Not -Match '(Local|_)/Standalone'
        ($Findings | Format-Table | Out-String -Width 240) | Should -Match Standalone
        $Findings[0].ToString() | Should -Match 'Information Standalone:'
        $Proposal = Resolve-NitpickCorrectionProposal -Script '$Value = 1' -Finding $Findings
        $Proposal.Conflicts[0].Reason | Should -Match "rule 'Standalone'"
        foreach ($Finding in $Findings) {
            $Finding.RuleId | Should -BeNullOrEmpty
            $Finding.Corrections[0].RuleId | Should -BeNullOrEmpty
        }
    }

    It 'owns parser diagnostics without introducing a selectable rule or registration' {
        $Output = @(Start-Nitpicking -Script 'if (' -Output Object -ErrorAction SilentlyContinue)
        $Findings = @($Output | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Findings.Count | Should -BeGreaterThan 0
        foreach ($Finding in $Findings) {
            $Finding.RuleId | Should -Be 'Nitpick/PowerShellParseError'
            $Finding.ToString() | Should -Match 'Nitpick/PowerShellParseError'
        }
        (Start-Nitpicking -Script 'if (' -NoSummary -ErrorAction SilentlyContinue) -join "`n" |
            Should -Match 'Nitpick/PowerShellParseError'
        @(Get-Nitpick) | Should -HaveCount 0
        { Start-Nitpicking -Script {} -IncludeRule Nitpick/PowerShellParseError } |
            Should -Throw '*No Nitpick rules match*'
    }
}
