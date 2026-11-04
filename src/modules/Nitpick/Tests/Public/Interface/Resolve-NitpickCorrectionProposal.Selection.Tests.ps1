using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../../../../AstEditor/AstEditor.psd1') -Force
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force

    function New-CompetingFinding {
        param (
            [IScriptExtent] $Extent,
            [object[]] $Correction,
            [string] $RuleName = 'CompetingRule'
        )

        New-NitpickFinding `
            -RuleId "Local/$RuleName" `
            -Message 'Competing correction.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises correction selection and attribution.' `
            -Corrections $Correction `
            -OutputAs NitpickFinding
    }
}

Describe 'Correction proposal selection and failure diagnostics' -Tag 'AutocorrectionContract' {
    BeforeEach {
        $Source = '-not ($Value -is [int]); -not ($Other -is [string])'
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))
        $FirstCorrection = $Findings[0].Corrections[0]
        $SecondCorrection = $Findings[1].Corrections[0]
    }

    It 'returns exactly the proposal schema without application or derived finding groups' {
        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Properties = @(
            'Path', 'SourcePath', 'Document', 'OriginalFingerprint', 'Status', 'OriginalText', 'OriginalFragmentText',
            'OriginalFindings', 'CandidateText', 'CandidateFragmentText', 'CandidateFindings', 'UndecidedFindings', 'SkippedFindings', 'WasReanalyzed',
            'AcceptedCorrections', 'SkippedCorrections', 'Conflicts', 'ParseErrors', 'Diff'
        )

        (Get-Command Resolve-NitpickCorrectionProposal).OutputType.Name | Should -Contain 'NitpickCorrectionProposal'
        $Proposal.PSTypeNames[0] | Should -Be 'NitpickCorrectionProposal'
        $Proposal.GetType().Name | Should -Be 'NitpickCorrectionProposal'
        (Get-Module Nitpick).ExportedFunctions.Keys | Should -Contain 'Resolve-NitpickCorrectionProposal'
        (Get-Module Nitpick).ExportedFunctions.Keys | Should -Not -Contain 'Resolve-NitpickCorrection'
        $Proposal.PSObject.Properties.Name | Should -HaveCount $Properties.Count

        foreach ($Property in $Properties) {
            $Proposal.PSObject.Properties.Name | Should -Contain $Property
        }

        foreach ($Removed in @('RenderedText', 'Findings', 'Corrections', 'Application', 'Report', 'WriteStatus', 'WasWritten')) {
            $Proposal.PSObject.Properties.Name | Should -Not -Contain $Removed
        }

        $Proposal.Status | Should -Be 'Ready'
        $Proposal.OriginalText | Should -BeExactly $Source
        [object]::ReferenceEquals($Proposal.Document, $Document) | Should -BeTrue

        foreach ($Property in @('OriginalFindings', 'CandidateFindings', 'AcceptedCorrections', 'SkippedCorrections', 'Conflicts', 'ParseErrors')) {
            $Proposal.$Property -is [array] | Should -BeTrue
        }

        $Proposal.WasReanalyzed | Should -BeTrue
    }

    It 'keeps zero and single proposal collections as arrays: <Count>' -ForEach @(
        @{ CaseSource = '$Value = 1'; Count = 0; Status = 'NoChanges' }
        @{ CaseSource = 'param([Parameter(Mandatory=$true)] [string] $Name)'; Count = 1; Status = 'Ready' }
    ) {
        $Document = New-AstDocument -InputObject $CaseSource
        $Rule = New-Nitpick -Callable Test-AvoidParameterAttributeBool
        $Findings = @($Rule.Invoke($Document.Ast))

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Proposal.Status | Should -Be $Status

        foreach ($Property in @('OriginalFindings', 'AcceptedCorrections')) {
            $Proposal.$Property -is [array] | Should -BeTrue
            $Proposal.$Property | Should -HaveCount $Count
        }

        foreach ($Property in @('CandidateFindings', 'SkippedCorrections', 'Conflicts', 'ParseErrors')) {
            $Proposal.$Property -is [array] | Should -BeTrue
            $Proposal.$Property | Should -HaveCount 0
        }
    }

    It 'skips a <Applicability> correction but still selects an independent correction' -ForEach @(
        @{ Applicability = 'Review' }
        @{ Applicability = 'Unsafe' }
    ) {
        $FirstCorrection.Applicability = $Applicability

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule

        $Result.Status | Should -Be 'Ready'
        $Result.AcceptedCorrections | Should -HaveCount 1
        $Result.SkippedCorrections | Should -HaveCount 1
        $Result.Conflicts | Should -HaveCount 0

        $Result.SkippedCorrections[0].Correction | Should -Be $FirstCorrection
        $Result.SkippedCorrections[0].Reason | Should -BeExactly "Applicability '$Applicability' is not selected."
        [object]::ReferenceEquals($Result.AcceptedCorrections[0], $SecondCorrection) | Should -BeTrue

        $Document.Edits.Count | Should -Be 2

        $Result.CandidateText | Should -BeExactly '-not ($Value -is [int]);  ($Other -isnot [string])'
        $Result.CandidateFindings | Should -HaveCount 1
        $Result.CandidateFindings[0].ViolationExtent.StartOffset | Should -Be 0
    }

    It 'skips a correction that has no native edit' {
        $Original = $FirstCorrection
        $Findings[0].Corrections[0] = New-NitpickCorrection `
            -StartLineNumber $Original.StartLineNumber `
            -EndLineNumber $Original.EndLineNumber `
            -StartColumnNumber $Original.StartColumnNumber `
            -EndColumnNumber $Original.EndColumnNumber `
            -ReplacementText '' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description $Original.Description `
            -RuleId $Original.RuleId

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Result.AcceptedCorrections | Should -HaveCount 1
        $Result.SkippedCorrections | Should -HaveCount 1
        $Result.SkippedCorrections[0].Reason | Should -BeExactly 'Correction does not contain an AstEditor text edit.'
        $Result.CandidateText | Should -BeExactly '-not ($Value -is [int]);  ($Other -isnot [string])'

        $Document.Edits.Count | Should -Be 2
    }

    It 'rejects all selected corrections when one authoritative edit is stale' {
        $FirstCorrection.TextEdits[1].ExpectedText = '-IS'

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule

        $Result.Status | Should -Be 'Rejected'
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.Conflicts | Should -HaveCount 0

        foreach ($Skipped in $Result.SkippedCorrections) {
            $Skipped.Reason | Should -BeExactly 'AstEditor rejected the target because an edit is stale.'
            $Skipped.Correction.RuleId | Should -Be 'Nitpick/UseIsNotOperator'
            $Skipped.Correction.TextEdits | Should -HaveCount 2
        }

        $Document.Edits.Count | Should -Be 0

        $Result.CandidateText | Should -BeExactly $Source
        $Result.OriginalText | Should -BeExactly $Source
        $Result.OriginalFindings | Should -HaveCount 2
    }

    It 'attributes conflicts with matching ranges and reasons to distinct producers: <Label>' -ForEach @(
        @{ Label = 'different replacements'; Replacement = '-is'; CompetingFirst = $false }
        @{ Label = 'identical replacements'; Replacement = '-isnot'; CompetingFirst = $false }
        @{ Label = 'different replacements in reverse order'; Replacement = '-is'; CompetingFirst = $true }
        @{ Label = 'identical replacements in reverse order'; Replacement = '-isnot'; CompetingFirst = $true }
    ) {
        $OperatorEdit = $FirstCorrection.TextEdits[1]
        $Edit = New-AstTextEdit `
            -Document $Document `
            -StartOffset $OperatorEdit.StartOffset `
            -EndOffset $OperatorEdit.EndOffset `
            -ReplacementText $Replacement `
            -Reason $OperatorEdit.Reason

        $CompetingCorrection = New-NitpickCorrection `
            -TextEdit $Edit `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Competing operator replacement.' `
            -RuleId 'Local/CompetingRule'

        $CompetingFinding = New-CompetingFinding `
            -Extent $Findings[0].ViolationExtent `
            -Correction $CompetingCorrection

        $OrderedFindings = if ($CompetingFirst) {
            @($CompetingFinding) + $Findings
        } else {
            @($Findings) + $CompetingFinding
        }

        $Result = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $OrderedFindings `
            -Rule $Rule

        $Result.Status | Should -Be 'Rejected'
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 3
        $Result.Conflicts | Should -HaveCount 1

        $Conflict = $Result.Conflicts[0]

        $ExpectedExisting = if ($CompetingFirst) { $CompetingCorrection } else { $FirstCorrection }
        $ExpectedIncoming = if ($CompetingFirst) { $FirstCorrection } else { $CompetingCorrection }

        [object]::ReferenceEquals($Conflict.ExistingCorrection, $ExpectedExisting) | Should -BeTrue
        [object]::ReferenceEquals($Conflict.IncomingCorrection, $ExpectedIncoming) | Should -BeTrue

        foreach ($Correction in @($FirstCorrection, $CompetingCorrection)) {
            $Conflict.Reason | Should -Match ([regex]::Escape($Correction.RuleId))
            $Conflict.Reason | Should -Match ([regex]::Escape($Correction.Description))
        }

        $Range = '[{0}, {1})' -f $OperatorEdit.StartOffset, $OperatorEdit.EndOffset
        $Conflict.Reason | Should -Match ([regex]::Escape($Range))

        $Document.Edits.Count | Should -Be 0
        $Result.CandidateText | Should -BeExactly $Source
        $Result.OriginalFindings | Should -HaveCount 3
    }

    It 'skips all of a finding''s corrections when it proposes several Safe alternatives' {
        $Alternative = New-NitpickCorrection `
            -ViolationExtent $Findings[0].ViolationExtent `
            -ReplacementText '($Value -isnot [int])' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Alternative rewrite of the negated type test.' `
            -RuleId 'Nitpick/UseIsNotOperator'
        $Findings[0].Corrections = @($FirstCorrection, $Alternative)

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule

        $Result.Status | Should -Be 'Ready'
        $Result.AcceptedCorrections | Should -HaveCount 1
        [object]::ReferenceEquals($Result.AcceptedCorrections[0], $SecondCorrection) | Should -BeTrue
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.Conflicts | Should -HaveCount 0

        foreach ($Skipped in $Result.SkippedCorrections) {
            $Skipped.Correction | Should -BeIn @($FirstCorrection, $Alternative)
            $Skipped.Reason | Should -BeExactly (
                'The finding proposes 2 Safe corrections; automatic selection never chooses between alternatives.')
        }

        $Document.Edits.Count | Should -Be 2
        $Result.CandidateText | Should -BeExactly '-not ($Value -is [int]);  ($Other -isnot [string])'
    }

    It 'selects the single Safe correction when alternatives are not Safe' {
        $Alternative = New-NitpickCorrection `
            -ViolationExtent $Findings[0].ViolationExtent `
            -ReplacementText '($Value -isnot [int])' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Editor-surfaced alternative.' `
            -RuleId 'Nitpick/UseIsNotOperator' `
            -Applicability Review
        $Findings[0].Corrections = @($FirstCorrection, $Alternative)

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule

        $Result.Status | Should -Be 'Ready'
        $Result.AcceptedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections | Should -HaveCount 1
        $Result.SkippedCorrections[0].Correction | Should -Be $Alternative
        $Result.SkippedCorrections[0].Reason | Should -BeExactly "Applicability 'Review' is not selected."
        $Result.Conflicts | Should -HaveCount 0

        $Document.Edits.Count | Should -Be 4
        $Result.CandidateText | Should -BeExactly ' ($Value -isnot [int]);  ($Other -isnot [string])'
    }

    It 'rejects the complete rendered batch when a correction produces parse errors' {
        $FirstCorrection.TextEdits[1].ReplacementText = '('

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Result.Status | Should -Be 'FailedValidation'
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.ParseErrors.Count | Should -BeGreaterThan 0
        $Result.CandidateText | Should -BeExactly ' ($Value ( [int]);  ($Other -isnot [string])'
        $Result.OriginalText | Should -BeExactly $Source
        $Result.OriginalFindings | Should -HaveCount 2
        $Result.WasReanalyzed | Should -BeFalse
        $Result.CandidateFindings | Should -HaveCount 0
    }
}
