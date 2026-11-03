BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force

    function New-SelectorFixture {
        param (
            [string[]] $Applicability = @('Safe')
        )

        $Path = Join-Path $TestDrive "Selector-$([guid]::NewGuid().ToString('N')).ps1"
        [System.IO.File]::WriteAllText($Path, 'param([Parameter(Mandatory=$true)] $MyParam)')
        $Document = New-AstDocument -Path $Path
        $Rule = New-Nitpick -Callable Test-AvoidParameterAttributeBool
        $Findings = @($Rule.Invoke($Document.Ast))
        $Template = $Findings[0].Corrections[0]

        # Distinct correction objects sharing the template's edits, so the selector's
        # return can be identified by reference and non-chosen ones can be reported.
        $Findings[0].Corrections = @(
            foreach ($Value in $Applicability) {
                New-NitpickCorrection `
                    -TextEdit $Template.TextEdits `
                    -FilePathOrContext $Path `
                    -Description "$Value alternative" `
                    -Applicability $Value `
                    -RuleId 'Nitpick/AvoidParameterAttributeBool'
            }
        )

        [pscustomobject]@{
            Path = $Path
            Document = $Document
            Findings = $Findings
        }
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickCorrectionProposal correction selector' {
    It 'does not invoke the selector when a single Safe correction needs no choice' {
        $Fixture = New-SelectorFixture -Applicability 'Safe'
        $Calls = [System.Collections.Generic.List[object]]::new()

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Fixture.Findings `
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
        $Fixture = New-SelectorFixture -Applicability $Applicability
        $Calls = [System.Collections.Generic.List[object]]::new()

        $null = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Fixture.Findings `
            -CorrectionSelector {
                param($Finding, $Corrections, $Document)
                $Calls.Add(@{ Finding = $Finding; Corrections = $Corrections; Document = $Document })
                $Corrections[0]
            }

        $Calls.Count | Should -Be 1
        [object]::ReferenceEquals($Calls[0].Finding, $Fixture.Findings[0]) | Should -BeTrue
        $Calls[0].Corrections | Should -HaveCount $Applicability.Count
        [object]::ReferenceEquals($Calls[0].Document, $Fixture.Document) | Should -BeTrue
    }

    It 'accepts the chosen <Applicability> correction as consent without recording the alternative as skipped' -ForEach @(
        @{ Applicability = 'Review' }
        @{ Applicability = 'Unsafe' }
    ) {
        $Fixture = New-SelectorFixture -Applicability 'Safe', $Applicability
        $Chosen = $Fixture.Findings[0].Corrections[1]

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Fixture.Findings `
            -CorrectionSelector { param($Finding, $Corrections) $Corrections[1] }

        $Proposal.Status | Should -Be 'Ready'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        [object]::ReferenceEquals($Proposal.AcceptedCorrections[0], $Chosen) | Should -BeTrue
        $Proposal.SkippedCorrections | Should -HaveCount 0
        $Proposal.SkippedFindings | Should -HaveCount 0
        $Proposal.UndecidedFindings | Should -HaveCount 0
    }

    It 'skips the finding without marking it undecided when the selector returns nothing' {
        $Fixture = New-SelectorFixture -Applicability 'Safe', 'Safe'

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Fixture.Findings `
            -CorrectionSelector { }

        $Proposal.Status | Should -Be 'NoChanges'
        $Proposal.AcceptedCorrections | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount 2
        $Proposal.SkippedCorrections.Reason | Should -Be @(
            'The finding was skipped during guided selection.'
            'The finding was skipped during guided selection.'
        )
        $Proposal.SkippedFindings | Should -HaveCount 1
        [object]::ReferenceEquals($Proposal.SkippedFindings[0], $Fixture.Findings[0]) | Should -BeTrue
        $Proposal.UndecidedFindings | Should -HaveCount 0
    }

    It 'throws when the selector returns a correction that was not offered' {
        $Fixture = New-SelectorFixture -Applicability 'Safe', 'Safe'
        $Foreign = New-NitpickCorrection `
            -TextEdit $Fixture.Findings[0].Corrections[0].TextEdits `
            -FilePathOrContext $Fixture.Path `
            -Description 'Not offered' `
            -RuleId 'Nitpick/AvoidParameterAttributeBool'

        {
            Resolve-NitpickCorrectionProposal `
                -Document $Fixture.Document `
                -Finding $Fixture.Findings `
                -CorrectionSelector { $Foreign }
        } | Should -Throw '*must return one of the corrections offered*'
    }

    It 'reports <Label> as undecided without a selector' -ForEach @(
        @{ Label = 'several Safe corrections'; Applicability = 'Safe', 'Safe'; Reason = 'never chooses between alternatives' }
        @{ Label = 'a lone Review correction'; Applicability = , 'Review'; Reason = "Applicability 'Review' is not selected." }
        @{ Label = 'only non-Safe corrections'; Applicability = 'Review', 'Unsafe'; Reason = 'is not selected' }
    ) {
        $Fixture = New-SelectorFixture -Applicability $Applicability

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Fixture.Document -Finding $Fixture.Findings

        $Proposal.Status | Should -Be 'NoChanges'
        $Proposal.UndecidedFindings | Should -HaveCount 1
        [object]::ReferenceEquals($Proposal.UndecidedFindings[0], $Fixture.Findings[0]) | Should -BeTrue
        $Proposal.SkippedFindings | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount $Applicability.Count
        $Proposal.SkippedCorrections[0].Reason | Should -Match $Reason
    }

    It 'selects the single Safe correction automatically alongside a non-Safe alternative' {
        $Fixture = New-SelectorFixture -Applicability 'Safe', 'Unsafe'

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Fixture.Document -Finding $Fixture.Findings

        $Proposal.Status | Should -Be 'Ready'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.AcceptedCorrections[0].Applicability | Should -Be 'Safe'
        $Proposal.UndecidedFindings | Should -HaveCount 0
        $Proposal.SkippedCorrections[0].Reason | Should -BeExactly "Applicability 'Unsafe' is not selected."
    }

    It 'exposes SourcePath for <Label>' -ForEach @(
        @{ Label = 'a file-backed document'; Kind = 'File' }
        @{ Label = 'a nested AST with provenance'; Kind = 'Nested' }
        @{ Label = 'a plain string'; Kind = 'String' }
    ) {
        $Source = 'param([Parameter(Mandatory=$true)] $MyParam)'
        $Path = Join-Path $TestDrive 'Provenance.ps1'
        $Document = switch ($Kind) {
            'File' {
                [System.IO.File]::WriteAllText($Path, $Source)
                New-AstDocument -Path $Path
            }
            'Nested' {
                [System.IO.File]::WriteAllText($Path, "& {$Source}")
                $Tokens = $null
                $Errors = $null
                $Root = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $Tokens, [ref] $Errors)
                $Nested = $Root.Find({
                    param($Node)
                    $Node -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
                }, $true).ScriptBlock
                New-AstDocument -InputObject $Nested
            }
            'String' { New-AstDocument -InputObject $Source }
        }
        $Rule = New-Nitpick -Callable Test-AvoidParameterAttributeBool
        $Findings = @($Rule.Invoke($Document.Ast))

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document -Finding $Findings

        if ($Kind -eq 'String') {
            $Proposal.SourcePath | Should -BeNullOrEmpty
            $Proposal.Path | Should -Be '<ScriptBlock>'
        } else {
            $Proposal.SourcePath | Should -Be $Path
            $Proposal.Path | Should -Be $(if ($Kind -eq 'File') { $Path } else { '<ScriptBlock>' })
        }
    }
}
