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
            -RuleName $RuleName `
            -Message 'Competing correction.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -RuleSuppressionID $RuleName `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises correction selection and attribution.' `
            -Corrections $Correction `
            -OutputAs NitpickFinding
    }
}

Describe 'Correction proposal change-set selection and failure diagnostics' -Tag 'AutocorrectionContract' {
    BeforeEach {
        $Source = '-not ($Value -is [int]); -not ($Other -is [string])'
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))
        $FirstGroup = $Findings[0].Corrections
        $SecondGroup = $Findings[1].Corrections
    }

    It 'returns exactly the proposal schema without application or derived finding groups' {
        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Properties = @(
            'Path', 'Document', 'OriginalFingerprint', 'Status', 'OriginalText',
            'OriginalFindings', 'CandidateText', 'CandidateFindings', 'WasReanalyzed',
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

    It 'skips both members when one is <Applicability> but still selects an independent group' -ForEach @(
        @{ Applicability = 'Review' }
        @{ Applicability = 'Unsafe' }
    ) {
        $FirstGroup[1].Applicability = $Applicability

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule

        $Result.Status | Should -Be 'Ready'
        $Result.AcceptedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.Conflicts | Should -HaveCount 0

        foreach ($Skipped in $Result.SkippedCorrections) {
            $Skipped.Correction | Should -BeIn $FirstGroup
            $Skipped.Reason | Should -BeExactly "Applicability '$Applicability' is not selected."
        }

        foreach ($Accepted in $Result.AcceptedCorrections) {
            $Accepted | Should -BeIn $SecondGroup
        }

        $Document.Edits.Count | Should -Be 2

        $Result.CandidateText | Should -BeExactly '-not ($Value -is [int]);  ($Other -isnot [string])'
        $Result.CandidateFindings | Should -HaveCount 1
        $Result.CandidateFindings[0].ViolationExtent.StartOffset | Should -Be 0
    }

    It 'skips the complete group when one member has no native edit' {
        $Original = $FirstGroup[1]
        $Findings[0].Corrections[1] = New-NitpickCorrection `
            -StartLineNumber $Original.StartLineNumber `
            -EndLineNumber $Original.EndLineNumber `
            -StartColumnNumber $Original.StartColumnNumber `
            -EndColumnNumber $Original.EndColumnNumber `
            -ReplacementText $Original.ReplacementText `
            -FilePathOrContext '<ScriptBlock>' `
            -Description $Original.Description `
            -ChangeSetId $Original.ChangeSetId `
            -RuleName $Original.RuleName

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Result.AcceptedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections.Reason | Should -Contain 'Correction does not contain an AstEditor text edit.'
        $Result.CandidateText | Should -BeExactly '-not ($Value -is [int]);  ($Other -isnot [string])'

        $Document.Edits.Count | Should -Be 2
    }

    It 'rejects all selected groups when one authoritative edit is stale' {
        $FirstGroup[1].TextEdit.ExpectedText = '-IS'

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule

        $Result.Status | Should -Be 'Rejected'
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 4
        $Result.Conflicts | Should -HaveCount 0

        foreach ($Skipped in $Result.SkippedCorrections) {
            $Skipped.Reason | Should -BeExactly 'AstEditor rejected the target because an edit is stale.'
            $Skipped.Correction.RuleName | Should -Be 'UseIsNotOperator'
            $Skipped.Correction.ChangeSetId | Should -Not -BeNullOrEmpty
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
        $Original = $FirstGroup[1]
        $Edit = New-AstTextEdit `
            -Document $Document `
            -StartOffset $Original.TextEdit.StartOffset `
            -EndOffset $Original.TextEdit.EndOffset `
            -ReplacementText $Replacement `
            -Reason $Original.TextEdit.Reason

        $CompetingCorrection = New-NitpickCorrection `
            -TextEdit $Edit `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Competing operator replacement.' `
            -RuleName 'CompetingRule' `
            -ChangeSetId 'CompetingRule:operator'

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
        $Result.SkippedCorrections | Should -HaveCount 5
        $Result.Conflicts | Should -HaveCount 1

        $Conflict = $Result.Conflicts[0]

        $ExpectedExisting = if ($CompetingFirst) { $CompetingCorrection } else { $Original }
        $ExpectedIncoming = if ($CompetingFirst) { $Original } else { $CompetingCorrection }

        [object]::ReferenceEquals($Conflict.ExistingCorrection, $ExpectedExisting) | Should -BeTrue
        [object]::ReferenceEquals($Conflict.IncomingCorrection, $ExpectedIncoming) | Should -BeTrue

        foreach ($Correction in @($Original, $CompetingCorrection)) {
            $Conflict.Reason | Should -Match ([regex]::Escape($Correction.RuleName))
            $Conflict.Reason | Should -Match ([regex]::Escape($Correction.ChangeSetId))
            $Range = '[{0}, {1})' -f $Correction.StartOffset, $Correction.EndOffset
            $Conflict.Reason | Should -Match ([regex]::Escape($Range))
        }

        $Document.Edits.Count | Should -Be 0
        $Result.CandidateText | Should -BeExactly $Source
        $Result.OriginalFindings | Should -HaveCount 3
    }

    It 'preserves target-wide grouping when different rules deliberately share an ID' {
        $Original = $FirstGroup[1]
        $Edit = New-AstTextEdit -Extent $Document.Ast.EndBlock.Statements[1].Extent `
            -ReplacementText '($Other -isnot [string])' -Reason 'Independent review edit.'

        $Correction = New-NitpickCorrection -TextEdit $Edit `
            -FilePathOrContext '<ScriptBlock>' -Description $Edit.Reason `
            -RuleName 'CompetingRule' -ChangeSetId $Original.ChangeSetId -Applicability Review

        $Competing = New-CompetingFinding -Extent $Findings[1].ViolationExtent -Correction $Correction

        $Result = Resolve-NitpickCorrectionProposal -Document $Document `
            -Finding @($Findings[0], $Competing)

        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 3
        $Result.Conflicts | Should -HaveCount 0
        $Result.CandidateText | Should -BeExactly $Source

        $Document.Edits.Count | Should -Be 0
    }

    It 'keeps namespaced groups independent when rule-local labels coincide' {
        foreach ($Correction in $FirstGroup) {
            $Correction.ChangeSetId = 'UseIsNotOperator:local'
        }
        $Edit = New-AstTextEdit -Extent $Document.Ast.EndBlock.Statements[1].Extent `
            -ReplacementText '($Other -isnot [string])' -Reason 'Independent review edit.'

        $Correction = New-NitpickCorrection -TextEdit $Edit `
            -FilePathOrContext '<ScriptBlock>' -Description $Edit.Reason `
            -RuleName 'CompetingRule' -ChangeSetId 'CompetingRule:local' -Applicability Review

        $Competing = New-CompetingFinding -Extent $Findings[1].ViolationExtent -Correction $Correction

        $Result = Resolve-NitpickCorrectionProposal -Document $Document `
            -Finding @($Findings[0], $Competing)

        $Result.AcceptedCorrections | Should -HaveCount 2
        $Result.SkippedCorrections | Should -HaveCount 1
        $Result.SkippedCorrections[0].Correction | Should -Be $Correction
        $Result.Conflicts | Should -HaveCount 0
        $Result.CandidateText | Should -BeExactly ' ($Value -isnot [int]); -not ($Other -is [string])'
    }

    It 'rejects the complete rendered batch when a group produces parse errors' {
        $FirstGroup[1].TextEdit.ReplacementText = '('

        $Result = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings -Rule $Rule
        $Result.Status | Should -Be 'FailedValidation'
        $Result.AcceptedCorrections | Should -HaveCount 0
        $Result.SkippedCorrections | Should -HaveCount 4
        $Result.ParseErrors.Count | Should -BeGreaterThan 0
        $Result.CandidateText | Should -BeExactly ' ($Value ( [int]);  ($Other -isnot [string])'
        $Result.OriginalText | Should -BeExactly $Source
        $Result.OriginalFindings | Should -HaveCount 2
        $Result.WasReanalyzed | Should -BeFalse
        $Result.CandidateFindings | Should -HaveCount 0
    }
}
