BeforeAll {
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
            $Findings[0].Corrections[1].TextEdit.ReplacementText = '('
        }
        if ($Conflict) {
            $Findings[0].Corrections += New-NitpickCorrection `
                -ViolationExtent $Document.Ast.EndBlock.Statements[0].Extent `
                -ReplacementText '$Other' `
                -FilePathOrContext $Document.Path `
                -Description 'Conflicting replacement' `
                -RuleName ConflictRule
        }
        $Rules = if ($NoReanalysis) { @() } else { @($Rule) }
        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rules
        [pscustomobject]@{
            Document = $Document
            Findings = $Findings
            Rules = @($Rules)
            Proposal = $Proposal
        }
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickTargetCorrection application and report ownership' {
    It 'declares the direct envelope contract without obsolete orchestration parameters' {
        InModuleScope Nitpick {
            $Command = Get-Command Resolve-NitpickTargetCorrection
            $Command.OutputType.Name | Should -Contain 'NitpickCorrectionResult'
            foreach ($Parameter in @('Document', 'Finding', 'Rule', 'Preview', 'WhatIf', 'Confirm')) {
                $Command.Parameters.Keys | Should -Contain $Parameter
            }
            $Command.Parameters.Keys | Should -Not -Contain 'Fix'
            $Command.Parameters.Keys | Should -Not -Contain 'Summary'
        }
    }

    It 'uses AnalysisSource for findings rather than effective text when reanalysis is unavailable' {
        #===  ARRANGE  ===#
        $Fixture = New-TargetCorrectionFixture -NoReanalysis
        $Before = (Get-TargetProposalSnapshot $Fixture.Proposal)
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'In-memory targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -WhatIf
        }

        #===  ASSERT  ===#
        $Result.PSTypeNames[0] | Should -Be 'NitpickCorrectionResult'
        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Application.CommittedCorrections | Should -HaveCount 0

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
        @{ Status = 'Preview'; Preview = $true; NoReanalysis = $false }
        @{ Status = 'Preview'; Preview = $true; NoReanalysis = $true }
        @{ Status = 'InMemory'; Preview = $false; NoReanalysis = $false }
        @{ Status = 'InMemory'; Preview = $false; NoReanalysis = $true }
    ) {
        $Fixture = New-TargetCorrectionFixture -NoReanalysis:$NoReanalysis
        $Before = Get-TargetProposalSnapshot $Fixture.Proposal
        Mock Resolve-NitpickCorrectionProposal -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'In-memory targets must not be saved.' }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture; Preview = $Preview } {
            param ($Fixture, $Preview)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -Preview:$Preview `
                -Confirm:$false
        }

        $Result.Application.Status | Should -Be $Status
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0
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
                -Confirm:$false
        }

        #===  ASSERT  ===#
        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue

        $Result.Application.Status | Should -Be 'Written'
        $Result.Application.CommittedCorrections | Should -HaveCount 2
        $Result.Application.WriteResult.WasWritten | Should -BeTrue

        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveText | Should -Be ' ($Value -isnot [int])'

        $Result.Report.EffectiveFindings -is [array] | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 0

        $Result.Report.FindingsWithCommittedCorrections -is [array] | Should -BeTrue
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 1
        $Result.Report.FindingsWithCommittedCorrections[0] | Should -Be $Fixture.Findings[0]

        $Fixture.Proposal.WasReanalyzed | Should -BeTrue

        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Result.Proposal.CandidateText
    }

    It 'reports candidate text but original analysis without reanalysis under <Status>' -ForEach @(
        @{ Status = 'Preview'; Preview = $true; WhatIf = $false }
        @{ Status = 'WhatIf'; Preview = $false; WhatIf = $true }
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
            Preview = $Preview
            WhatIf = $WhatIf
        } {
            param ($Fixture, $Preview, $WhatIf)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -Rule $Fixture.Rules `
                -Preview:$Preview `
                -WhatIf:$WhatIf `
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Application.Status | Should -Be $Status
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.CandidateText
        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0

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
                -Confirm:$false
        }

        #===  ASSERT  ===#
        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue
        $Result.Application.Status | Should -Be $Status
        $Result.Application.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.Application.CommittedCorrections -is [array] | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
        $Result.Proposal.SkippedCorrections | Should -HaveCount 2
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
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0
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
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Declined targets must not be saved.' }

        #===  ACT  ===#
        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            $Command = Get-Command Resolve-NitpickTargetCorrection

            $ShouldProcessCall = $Command.ScriptBlock.Ast.Find({
                param ($Node)
                $Node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                    $Node.Member.Value -eq 'ShouldProcess'
            }, $true)

            # Replace only this invocation's decision, without prompting or changing production code.
            $Breakpoint = Set-PSBreakpoint -Script $Command.ScriptBlock.File `
                -Line $ShouldProcessCall.Extent.StartLineNumber -Action {
                    $Invocation = (Get-Variable -Name PSCmdlet -Scope 1).Value
                    $Invocation | Add-Member -MemberType ScriptMethod -Name ShouldProcess -Value { $false } -Force
                }

            try {
                Resolve-NitpickTargetCorrection `
                    -Document $Fixture.Document `
                    -Finding $Fixture.Findings `
                    -Rule $Fixture.Rules `
                    -Confirm:$false
            } finally {
                $Breakpoint | Remove-PSBreakpoint
            }
        }

        #===  ASSERT  ===#
        $Result.Application.Status | Should -Be 'Declined'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.EffectiveFindings[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.SkippedCorrections | Should -HaveCount 2
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
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Proposal.Status | Should -Be 'NoChanges'
        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveFindings | Should -HaveCount 0
        $Result.Application.CommittedCorrections | Should -HaveCount 0
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
                -Confirm:$false
        }

        #===  ASSERT  ===#
        $Result.Proposal.Status | Should -Be $Status

        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]

        (Get-TargetProposalSnapshot $Fixture.Proposal) |
            Should -BeExactly $Before

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }
}
