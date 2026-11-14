BeforeAll {
    $PreviousQuietWhatIf = $env:WHATIF__QUIET
    $env:WHATIF__QUIET = $true

    Import-Module -Name "$PSScriptRoot\..\..\..\AstEditor\AstEditor.psd1" -Force
    Import-Module -Name "$PSScriptRoot\..\..\Nitpick.psd1" -Force

    function Get-TargetProposalSnapshot {
        param ([psobject] $Proposal)

        # CLR class serialization lazily caches nested adapters; snapshot the public values instead.
        $Properties = [ordered]@{}
        foreach ($Property in $Proposal.PSObject.Properties) {
            $Properties[$Property.Name] = $Property.Value
        }
        [System.Management.Automation.PSSerializer]::Serialize([pscustomobject] $Properties, 3)
    }

    function New-TargetCorrectionFixture {
        param (
            [string] $Path,
            [string] $Source = '-not ($Value -is [int])',
            [switch] $NoReanalysis,
            [switch] $Invalid,
            [switch] $Conflict,
            [switch] $RemainingFinding
        )

        if ($RemainingFinding) {
            $Source += '; -not ($Other -is [string])'
        }
        $Document = if ($Path) {
            [System.IO.File]::WriteAllText($Path, $Source)
            New-AstDocument -Path $Path
        } else {
            New-AstDocument -InputObject $Source
        }
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))
        if ($RemainingFinding) {
            foreach ($Correction in $Findings[1].Corrections) {
                $Correction.Applicability = 'Review'
            }
        }
        if ($Invalid) {
            $Findings[0].Corrections[0].TextEdits[1].ReplacementText = '('
        }
        if ($Conflict) {
            # The conflicting fix must come from a separate finding: two Safe
            # corrections on one finding are skipped as ambiguous alternatives
            # before any edit is queued.
            $ConflictCorrection = New-NitpickCorrection `
                -ViolationExtent $Document.Ast.EndBlock.Statements[0].Extent `
                -ReplacementText '$Other' `
                -FilePathOrContext $Document.Path `
                -Description 'Conflicting replacement' `
                -RuleId 'Local/ConflictRule'

            $Findings += New-NitpickFinding `
                -RuleId 'Local/ConflictRule' `
                -Message 'Conflicting fix.' `
                -ViolationExtent $Document.Ast.EndBlock.Statements[0].Extent `
                -Severity Information `
                -ScriptPath $Document.Path `
                -Explanation 'Overlaps the UseIsNotOperator fix.' `
                -Corrections $ConflictCorrection `
                -OutputAs NitpickFinding
        }

        $Rules = if ($NoReanalysis) { @() } else { @($Rule) }
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Findings `
            -Rule $Rules

        [pscustomobject]@{
            Document = $Document
            Findings = $Findings
            Rules = @($Rules)
            Proposal = $Proposal
        }
    }
}

AfterAll {
    $env:WHATIF__QUIET = $PreviousQuietWhatIf
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickTargetCorrection application and report ownership' {
    It 'declares the direct envelope contract without obsolete orchestration parameters' {
        InModuleScope Nitpick {
            $Command = Get-Command Resolve-NitpickTargetCorrection
            $Command.OutputType.Name | Should -Contain 'NitpickCorrectionResult'
            foreach ($Parameter in @('Document', 'Finding', 'Rule', 'FixMode', 'WhatIf', 'Confirm')) {
                $Command.Parameters.Keys | Should -Contain $Parameter
            }
            $Command.Parameters.Keys | Should -Not -Contain 'Fix'
            $Command.Parameters.Keys | Should -Not -Contain 'Summary'
        }
    }

    It 'forwards the canonical context to proposal resolution' {
        $Fixture = New-TargetCorrectionFixture -NoReanalysis
        $Context = @{ Caller = 'PolicyCoordinator'; Policy = @{} }
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick `
            -RemoveParameterValidation Document `
            -ParameterFilter { $Context.Caller -eq 'PolicyCoordinator' } {
                $Fixture.Proposal
            }

        $Result = InModuleScope Nitpick -Parameters @{
            Fixture = $Fixture
            Context = $Context
        } {
            param($Fixture, $Context)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Preview `
                -Context $Context
        }

        $Result.Proposal | Should -Be $Fixture.Proposal
        Should -Invoke Resolve-NitpickCorrectionProposal -ModuleName Nitpick -Times 1 -Exactly `
            -ParameterFilter { $Context.Caller -eq 'PolicyCoordinator' }
    }

    It 'uses AnalysisSource for findings rather than effective text when reanalysis is unavailable' {
        #===  ARRANGE  ===#
        $Fixture = New-TargetCorrectionFixture -NoReanalysis
        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'In-memory targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)

            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Apply `
                -WhatIf
        }

        #===  ASSERT  ===#
        $Result.PSTypeNames[0] | Should -Be 'NitpickCorrectionResult'
        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Application.AppliedCorrections | Should -HaveCount 1

        $Result.Report.EffectiveText | Should -Be ' ($Value -isnot [int])'
        $Result.Report.EffectiveText | Should -BeExactly $Fixture.Proposal.CandidateText
        $Result.Report.EffectiveText | Should -Not -BeExactly $Fixture.Proposal.OriginalText
        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveFindings -is [array] | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]

        $Result.Proposal.WasReanalyzed | Should -BeFalse
        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'reports in-memory <Status> with NoReanalysis=<NoReanalysis> without saving or changing the proposal' -ForEach @(
        @{ Status = 'Preview'; FixMode = 'Preview'; NoReanalysis = $false }
        @{ Status = 'Preview'; FixMode = 'Preview'; NoReanalysis = $true }
        @{ Status = 'InMemory'; FixMode = 'Apply'; NoReanalysis = $false }
        @{ Status = 'InMemory'; FixMode = 'Apply'; NoReanalysis = $true }
    ) {
        $Fixture = New-TargetCorrectionFixture -NoReanalysis:$NoReanalysis
        $Before = Get-TargetProposalSnapshot $Fixture.Proposal
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'In-memory targets must not be saved.' }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture; FixMode = $FixMode } {
            param($Fixture, $FixMode)

            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode $FixMode `
                -Confirm:$false
        }

        $Result.Application.Status | Should -Be $Status
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $ExpectedApplied = if ($Status -eq 'InMemory') { 1 } else { 0 }
        $Result.Application.AppliedCorrections | Should -HaveCount $ExpectedApplied
        $Result.Report.FindingsWithAppliedCorrections | Should -HaveCount $ExpectedApplied
        $Result.Report.FindingsWithAcceptedCorrections | Should -HaveCount 1
        $Result.Report.EffectiveText | Should -BeExactly $Fixture.Proposal.CandidateText
        $ExpectedAnalysis = if ($NoReanalysis) { 'Original' } else { 'Candidate' }
        $Result.Report.AnalysisSource | Should -Be $ExpectedAnalysis
        $ExpectedFindingCount = if ($NoReanalysis) { 1 } else { 0 }
        $Result.Report.EffectiveFindings | Should -HaveCount $ExpectedFindingCount
        (Get-TargetProposalSnapshot $Fixture.Proposal) | Should -BeExactly $Before
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'preserves the same proposal after a successful write and counts each original finding once' {
        #===  ARRANGE  ===#
        $Path = Join-Path $TestDrive 'Written.ps1'
        $Fixture = New-TargetCorrectionFixture -Path $Path
        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Apply `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue

        $Result.Application.Status | Should -Be 'Written'
        $Result.Application.AppliedCorrections | Should -HaveCount 1
        $Result.Application.WriteResult.WasWritten | Should -BeTrue

        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveText | Should -Be ' ($Value -isnot [int])'

        $Result.Report.EffectiveFindings -is [array] | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 0

        $Result.Report.FindingsWithAppliedCorrections -is [array] | Should -BeTrue
        $Result.Report.FindingsWithAppliedCorrections | Should -HaveCount 1
        $Result.Report.FindingsWithAppliedCorrections[0] | Should -Be $Fixture.Findings[0]

        $Result.Report.FindingsWithAcceptedCorrections | Should -HaveCount 1
        $Result.Report.FindingsWithAcceptedCorrections[0] | Should -Be $Fixture.Findings[0]

        $Fixture.Proposal.WasReanalyzed | Should -BeTrue

        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Result.Proposal.CandidateText
    }

    It 'reports candidate text but original analysis without reanalysis under <Status>' -ForEach @(
        @{ Status = 'Preview'; FixMode = 'Preview'; WhatIf = $false }
        @{ Status = 'WhatIf'; FixMode = 'Apply'; WhatIf = $true }
    ) {
        #===  ARRANGE  ===#
        $Path = Join-Path $TestDrive "$Status.ps1"
        $Fixture = New-TargetCorrectionFixture -Path $Path -NoReanalysis
        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Preview targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{
            Fixture = $Fixture
            FixMode = $FixMode
            WhatIf = $WhatIf
        } {
            param($Fixture, $FixMode, $WhatIf)

            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode $FixMode `
                -WhatIf:$WhatIf `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Application.Status | Should -Be $Status
        $Result.Application.AppliedCorrections | Should -HaveCount 0

        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.CandidateText
        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithAppliedCorrections | Should -HaveCount 0
        $Result.Report.FindingsWithAcceptedCorrections | Should -HaveCount 1

        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Fixture.Proposal.OriginalText
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'retains candidate identity and proposal skips after <Status> while reporting original findings' -ForEach @(
        @{ Status = 'FailedWrite' }
        @{ Status = 'StaleSource' }
    ) {
        #===  ARRANGE  ===#
        $Path = Join-Path $TestDrive "$Status.ps1"
        $Fixture = New-TargetCorrectionFixture -Path $Path -RemainingFinding
        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        if ($Status -eq 'FailedWrite') {
            Mock Invoke-AstFileReplacement -ModuleName AstEditor {
                throw [System.IO.IOException]::new('Simulated commit failure.')
            }
        } else {
            [System.IO.File]::WriteAllText($Path, '$External = 3')
        }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Apply `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue
        $Result.Application.Status | Should -Be $Status
        $Result.Application.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.Application.AppliedCorrections -is [array] | Should -BeTrue
        $Result.Application.AppliedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
        $Result.Proposal.SkippedCorrections | Should -HaveCount 1
        $Result.Proposal.CandidateFindings[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        foreach ($Correction in @($Result.Proposal.AcceptedCorrections) +
            @($Result.Proposal.SkippedCorrections.Correction) +
            @($Result.Proposal.CandidateFindings.Corrections)) {
            $Correction.RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        }

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings | Should -HaveCount 2
        $Result.Report.EffectiveFindings[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithAppliedCorrections | Should -HaveCount 0
        $Result.Report.FindingsWithAcceptedCorrections | Should -HaveCount 1
        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before
        $ExpectedDiskText = if ($Status -eq 'StaleSource') { '$External = 3' } else { $Fixture.Proposal.OriginalText }
        [System.IO.File]::ReadAllText($Path) | Should -Be $ExpectedDiskText
    }

    It 'preserves the proposal after a noninteractive decline and reports the original snapshot' {
        #===  ARRANGE  ===#
        $Path = Join-Path $TestDrive 'Declined.ps1'
        $Fixture = New-TargetCorrectionFixture -Path $Path -RemainingFinding
        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Should-Process -ModuleName Nitpick { $false }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Declined targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)

            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Apply `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Application.Status | Should -Be 'Declined'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.AppliedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.EffectiveFindings[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        $Result.Report.FindingsWithAppliedCorrections | Should -HaveCount 0
        $Result.Report.FindingsWithAcceptedCorrections | Should -HaveCount 1

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.SkippedCorrections | Should -HaveCount 1
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
        $Result.Proposal.CandidateFindings[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        foreach ($Correction in @($Result.Proposal.AcceptedCorrections) +
            @($Result.Proposal.SkippedCorrections.Correction) +
            @($Result.Proposal.CandidateFindings.Corrections)) {
            $Correction.RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        }

        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue
        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Fixture.Proposal.OriginalText
        Should -Invoke Should-Process -ModuleName Nitpick -Times 1 -Exactly
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'uses candidate analysis for NoChanges but never attempts a write' {
        #===  ARRANGE  ===#
        $Fixture = New-TargetCorrectionFixture -Path (Join-Path $TestDrive 'NoChanges.ps1') `
            -Source '($Value -isnot [int])'

        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Unchanged targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Apply `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Proposal.Status | Should -Be 'NoChanges'
        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveFindings | Should -HaveCount 0
        $Result.Application.AppliedCorrections | Should -HaveCount 0
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'does not apply a <Status> proposal and reports the original snapshot' -ForEach @(
        @{ Status = 'FailedValidation'; Invalid = $true; Conflict = $false }
        @{ Status = 'Rejected'; Invalid = $false; Conflict = $true }
    ) {
        #===  ARRANGE  ===#
        $Fixture = New-TargetCorrectionFixture -Path (Join-Path $TestDrive "$Status.ps1") `
            -Invalid:$Invalid -Conflict:$Conflict

        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)

        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Rejected targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -FixMode Apply `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Proposal.Status | Should -Be $Status

        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Application.AppliedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithAcceptedCorrections | Should -HaveCount 0

        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }
}
