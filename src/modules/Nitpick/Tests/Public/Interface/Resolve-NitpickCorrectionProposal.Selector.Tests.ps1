BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force
    . (Join-Path $PSScriptRoot '../../Support/CorrectionFixtures.ps1')
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickCorrectionProposal correction selector' {
    BeforeEach {
        $Fixture = New-TestSourceDocument
    }

    It 'does not invoke the selector when a single Safe correction needs no choice' {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe'
        $Calls = [System.Collections.Generic.List[object]]::new()

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Finding `
            -CorrectionSelector { $Calls.Add($args); $args[1][0] }

        $Calls.Count | Should -Be 0
        $Proposal.Status | Should -Be 'Ready'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.UndecidedFindings | Should -HaveCount 0
    }

    It 'invokes the selector with the finding, its corrections, and the document for <Label>' -ForEach @(
        @{ Label = 'alternatives'; Applicability = 'Safe', 'Safe' }
        @{ Label = 'a Safe and a Review correction'; Applicability = 'Safe', 'Review' }
        @{ Label = 'a lone Unsafe correction'; Applicability = , 'Unsafe' }
    ) {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability $Applicability
        $Calls = [System.Collections.Generic.List[object]]::new()

        $null = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Finding `
            -CorrectionSelector {
                param($Finding, $Corrections, $Document)
                $Calls.Add(@{ Finding = $Finding; Corrections = $Corrections; Document = $Document })
                $Corrections[0]
            }

        $Calls.Count | Should -Be 1
        [object]::ReferenceEquals($Calls[0].Finding, $Finding) | Should -BeTrue
        $Calls[0].Corrections | Should -HaveCount $Applicability.Count
        [object]::ReferenceEquals($Calls[0].Document, $Fixture.Document) | Should -BeTrue
    }

    It 'accepts the chosen <Applicability> correction as consent without recording the alternative as skipped' -ForEach @(
        @{ Applicability = 'Review' }
        @{ Applicability = 'Unsafe' }
    ) {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', $Applicability
        $Chosen = $Finding.Corrections[1]

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Finding `
            -CorrectionSelector { param($Finding, $Corrections) $Corrections[1] }

        $Proposal.Status | Should -Be 'Ready'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        [object]::ReferenceEquals($Proposal.AcceptedCorrections[0], $Chosen) | Should -BeTrue
        $Proposal.SkippedCorrections | Should -HaveCount 0
        $Proposal.SkippedFindings | Should -HaveCount 0
        $Proposal.UndecidedFindings | Should -HaveCount 0
    }

    It 'skips the finding without marking it undecided when the selector returns nothing' {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Safe'

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Finding `
            -CorrectionSelector { }

        $Proposal.Status | Should -Be 'NoChanges'
        $Proposal.AcceptedCorrections | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount 2
        $Proposal.SkippedCorrections.Reason | Should -Be @(
            'The finding was skipped during guided selection.'
            'The finding was skipped during guided selection.'
        )
        $Proposal.SkippedFindings | Should -HaveCount 1
        [object]::ReferenceEquals($Proposal.SkippedFindings[0], $Finding) | Should -BeTrue
        $Proposal.UndecidedFindings | Should -HaveCount 0
    }

    It 'throws when the selector returns a correction that was not offered' {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Safe'
        $Foreign = New-NitpickCorrection `
            -TextEdit $Finding.Corrections[0].TextEdits `
            -FilePathOrContext $Fixture.Path `
            -Description 'Not offered' `
            -RuleId 'Nitpick/AvoidParameterAttributeBool'

        {
            Resolve-NitpickCorrectionProposal `
                -Document $Fixture.Document `
                -Finding $Finding `
                -CorrectionSelector { $Foreign }
        } | Should -Throw '*must return one of the corrections offered*'
    }

    It 'reports <Label> as undecided without a selector' -ForEach @(
        @{ Label = 'several Safe corrections'; Applicability = 'Safe', 'Safe'; Reason = 'never chooses between alternatives' }
        @{ Label = 'a lone Review correction'; Applicability = , 'Review'; Reason = "Applicability 'Review' is not selected." }
        @{ Label = 'only non-Safe corrections'; Applicability = 'Review', 'Unsafe'; Reason = 'is not selected' }
    ) {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability $Applicability

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Fixture.Document -Finding $Finding

        $Proposal.Status | Should -Be 'NoChanges'
        $Proposal.UndecidedFindings | Should -HaveCount 1
        [object]::ReferenceEquals($Proposal.UndecidedFindings[0], $Finding) | Should -BeTrue
        $Proposal.SkippedFindings | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount $Applicability.Count
        $Proposal.SkippedCorrections[0].Reason | Should -Match $Reason
    }

    It 'selects the single Safe correction automatically alongside a non-Safe alternative' {
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Fixture.Document -Finding $Finding

        $Proposal.Status | Should -Be 'Ready'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.AcceptedCorrections[0].Applicability | Should -Be 'Safe'
        $Proposal.UndecidedFindings | Should -HaveCount 0
        $Proposal.SkippedCorrections[0].Reason | Should -BeExactly "Applicability 'Unsafe' is not selected."
    }

    It 'exposes SourcePath for <Kind> input' -ForEach @(
        @{ Kind = 'File'; ExpectSourcePath = $true; ExpectPathIsFile = $true }
        @{ Kind = 'Nested'; ExpectSourcePath = $true; ExpectPathIsFile = $false }
        @{ Kind = 'String'; ExpectSourcePath = $false; ExpectPathIsFile = $false }
    ) {
        $Fixture = New-TestSourceDocument -Kind $Kind
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe'

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Fixture.Document -Finding $Finding

        if ($ExpectSourcePath) {
            $Proposal.SourcePath | Should -Be $Fixture.Path
        } else {
            $Proposal.SourcePath | Should -BeNullOrEmpty
        }
        $Proposal.Path | Should -Be $(if ($ExpectPathIsFile) { $Fixture.Path } else { '<ScriptBlock>' })
    }
}

Describe 'Correction fixture invariants' {
    It 'produces distinct alternative objects' {
        $Fixture = New-TestSourceDocument
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Safe', 'Unsafe'

        $Finding.Corrections | Should -HaveCount 3
        { Assert-TestCorrectionsDistinct -Correction $Finding.Corrections } | Should -Not -Throw
        $Finding.Corrections.Applicability | Should -Be @('Safe', 'Safe', 'Unsafe')
    }

    It 'rejects a finding that lists one correction twice' {
        $Fixture = New-TestSourceDocument
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe'
        $Same = $Finding.Corrections[0]

        { Assert-TestCorrectionsDistinct -Correction @($Same, $Same) } |
            Should -Throw '*index 0 and 1 are the same object*'
    }

    It 'builds a <Kind> document with the expected provenance' -ForEach @(
        @{ Kind = 'File'; FileBacked = $true; Provenance = $true }
        @{ Kind = 'Nested'; FileBacked = $false; Provenance = $true }
        @{ Kind = 'String'; FileBacked = $false; Provenance = $false }
    ) {
        $Fixture = New-TestSourceDocument -Kind $Kind

        $Fixture.Document.IsFileBacked | Should -Be $FileBacked
        if ($Provenance) {
            $Fixture.Document.Ast.Extent.File | Should -Be $Fixture.Path
        } else {
            $Fixture.Document.Ast.Extent.File | Should -BeNullOrEmpty
        }
        if ($Kind -eq 'Nested') {
            $Fixture.Document.Ast.Extent.StartLineNumber | Should -Be 2
            $Fixture.Document.IsFragment | Should -BeTrue
            $Fixture.Document.Root.Ast.Extent.Text | Should -BeExactly $Fixture.FileText
            $Fixture.FragmentAst | Should -Not -BeNullOrEmpty
        }
    }
}
