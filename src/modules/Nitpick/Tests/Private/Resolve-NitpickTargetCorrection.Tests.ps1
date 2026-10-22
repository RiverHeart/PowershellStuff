BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\AstEditor\AstEditor.psd1" -Force
    Import-Module -Name "$PSScriptRoot\..\..\Nitpick.psd1" -Force

    function New-TargetCorrectionFixture {
        param (
            [string] $Path,
            [string] $Source = '-not ($Value -is [int])',
            [switch] $NoReanalysis,
            [switch] $Invalid,
            [switch] $Conflict
        )

        $Document = if ($Path) {
            [System.IO.File]::WriteAllText($Path, $Source)
            New-AstDocument -Path $Path
        } else {
            New-AstDocument -InputObject $Source
        }
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))
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
        $Proposal = Resolve-NitpickCorrection -Document $Document -Finding $Findings -Rule $Rules
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
            $Command.OutputType.Name | Should -Contain 'Nitpick.CorrectionResult'
            foreach ($Parameter in @('Document', 'Finding', 'Rule', 'Ast', 'Preview', 'WhatIf', 'Confirm')) {
                $Command.Parameters.Keys | Should -Contain $Parameter
            }
            $Command.Parameters.Keys | Should -Not -Contain 'Fix'
            $Command.Parameters.Keys | Should -Not -Contain 'Summary'
        }
    }

    It 'returns candidate text in memory but original findings without reanalysis' {
        $Fixture = New-TargetCorrectionFixture -NoReanalysis
        $Before = [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3)
        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'In-memory targets must not be saved.' }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -WhatIf
        }

        $Result.PSTypeNames[0] | Should -Be 'Nitpick.CorrectionResult'
        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.EffectiveText | Should -Be ' ($Value -isnot [int])'
        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveFindings -is [array] | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]

        $Result.Proposal.WasReanalyzed | Should -BeFalse
        [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3) |
            Should -BeExactly $Before

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'preserves the same proposal after a successful write and counts each original finding once' {
        $Path = Join-Path $TestDrive 'Written.ps1'
        $Fixture = New-TargetCorrectionFixture -Path $Path
        $Before = [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3)
        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -Confirm:$false
        }

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

        [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Result.Proposal.CandidateText
    }

    It 'reports candidate text but original analysis without reanalysis under <Status>' -ForEach @(
        @{ Status = 'Preview'; Preview = $true; WhatIf = $false }
        @{ Status = 'WhatIf'; Preview = $false; WhatIf = $true }
    ) {
        $Path = Join-Path $TestDrive "$Status.ps1"
        $Fixture = New-TargetCorrectionFixture -Path $Path -NoReanalysis
        $Before = [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3)
        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Preview targets must not be saved.' }

        $Result = InModuleScope Nitpick -Parameters @{
            Fixture = $Fixture
            Preview = $Preview
            WhatIf = $WhatIf
        } {
            param ($Fixture, $Preview, $WhatIf)
            Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -Preview:$Preview -WhatIf:$WhatIf -Confirm:$false
        }

        $Result.Application.Status | Should -Be $Status
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.CandidateText
        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0

        [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Fixture.Proposal.OriginalText
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'retains candidate analysis and proposal skips after a failed write while reporting original findings' {
        $Path = Join-Path $TestDrive 'FailedWrite.ps1'
        $Fixture = New-TargetCorrectionFixture -Path $Path
        $Before = [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3)
        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Invoke-AstFileReplacement -ModuleName AstEditor {
            throw [System.IO.IOException]::new('Simulated commit failure.')
        }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -Confirm:$false
        }

        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue
        $Result.Application.Status | Should -Be 'FailedWrite'
        $Result.Application.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.Application.CommittedCorrections -is [array] | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.CandidateFindings | Should -HaveCount 0
        $Result.Proposal.SkippedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be '-not ($Value -is [int])'
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0
        [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3) |
            Should -BeExactly $Before
        [System.IO.File]::ReadAllText($Path) | Should -Be $Fixture.Proposal.OriginalText
    }

    It 'preserves the proposal after a noninteractive decline and reports the original snapshot' {
        $Path = Join-Path $TestDrive 'Declined.ps1'
        $Fixture = New-TargetCorrectionFixture -Path $Path
        $Before = [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3)
        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Declined targets must not be saved.' }

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
                Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                    -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -Confirm:$false
            } finally {
                $Breakpoint | Remove-PSBreakpoint
            }
        }

        $Result.Application.Status | Should -Be 'Declined'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 0

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.SkippedCorrections | Should -HaveCount 0

        [object]::ReferenceEquals($Result.Proposal, $Fixture.Proposal) | Should -BeTrue
        [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3) |
            Should -BeExactly $Before

        [System.IO.File]::ReadAllText($Path) | Should -Be $Fixture.Proposal.OriginalText
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }

    It 'uses candidate analysis for NoChanges but never attempts a write' {
        $Fixture = New-TargetCorrectionFixture -Path (Join-Path $TestDrive 'NoChanges.ps1') `
            -Source '($Value -isnot [int])'

        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Unchanged targets must not be saved.' }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -Confirm:$false
        }

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
        $Fixture = New-TargetCorrectionFixture -Path (Join-Path $TestDrive "$Status.ps1") `
            -Invalid:$Invalid -Conflict:$Conflict

        $Before = [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3)

        Mock Resolve-NitpickCorrection -ModuleName Nitpick -RemoveParameterValidation Document { $Fixture.Proposal }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Rejected targets must not be saved.' }

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param ($Fixture)
            Resolve-NitpickTargetCorrection -Document $Fixture.Document -Finding $Fixture.Findings `
                -Rule $Fixture.Rules -Ast $Fixture.Document.Ast -Confirm:$false
        }

        $Result.Proposal.Status | Should -Be $Status

        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Report.EffectiveText | Should -Be $Fixture.Proposal.OriginalText
        $Result.Report.EffectiveFindings[0] | Should -Be $Fixture.Findings[0]

        [System.Management.Automation.PSSerializer]::Serialize($Fixture.Proposal, 3) |
            Should -BeExactly $Before

        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }
}
