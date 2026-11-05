using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
    . "$PSScriptRoot\..\..\Support\CorrectionFixtures.ps1"
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Snapshot-backed Nitpick fragments' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
        $Fixture = New-TestSourceDocument -Kind Nested -Source '$Value = 1' `
            -Prefix "`$Value = 1`r`n"

        $Rule = {
            param([ScriptBlockAst] $ScriptBlockAst, $Context)

            $Statement = $ScriptBlockAst.EndBlock.Statements[0]
            $Corrections = @()
            if ($Statement.Extent.Text -eq '$Value = 1') {
                $Corrections = @(
                    New-NitpickCorrection -ViolationExtent $Statement.Extent `
                        -ReplacementText '$Value = 200' -FilePathOrContext $Context.File `
                        -Description 'Length-changing correction'
                )
            }

            New-NitpickFinding `
                -RuleId 'Local/FragmentRule' `
                -Message "File=$($Context.File)" `
                -ViolationExtent $Statement.Extent `
                -Severity Information `
                -ScriptPath $Context.File `
                -Explanation 'Checks fragment reanalysis.' `
                -Corrections $Corrections
        }

        Register-Nitpick -Callable $Rule -Name FragmentRule -Source Tests
    }

    It 'keeps analysis, navigation coordinates, text, and disk boundaries consistent in <FixMode>' -ForEach @(
        @{ FixMode = 'Preview' }
        @{ FixMode = 'Apply' }
    ) {
        $Bytes = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Fixture.Path))
        $Output = @(
            Start-Nitpicking `
                -Script $Fixture.FragmentAst `
                -FixMode $FixMode `
                -IncludeRule Local/FragmentRule `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
        )

        $Result = $Output | Where-Object { $_.GetType().Name -eq 'NitpickCorrectionResult' }

        $Result.Proposal.Status | Should -Be 'Ready'
        $Result.Proposal.SourcePath | Should -BeExactly $Fixture.Path
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.OriginalText | Should -BeExactly $Fixture.FileText
        $Result.Proposal.CandidateText | Should -BeExactly "`$Value = 1`r`n& {`$Value = 200}"
        $Result.Report.EffectiveText | Should -BeExactly '{$Value = 200}'
        $Result.Proposal.OriginalFragmentText | Should -BeExactly '{$Value = 1}'
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Finding = $Result.Report.EffectiveFindings[0]
        $Finding.ViolationExtent.File | Should -BeExactly $Fixture.Path
        $Finding.ViolationExtent.StartLineNumber | Should -Be 2
        $Finding.ViolationExtent.StartColumnNumber | Should -Be 4
        $Finding.ViolationExtent.Text | Should -BeExactly '$Value = 200'
        $Finding.Message | Should -BeExactly "File=$($Fixture.Path)"
        $Result.Proposal.Document.IsFileBacked | Should -BeFalse

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Fixture.Path)) |
            Should -BeExactly $Bytes
    }

    It 'uses identical original finding coordinates with fix mode Off and Preview' {
        $Off = @(Start-Nitpicking -Script $Fixture.FragmentAst -FixMode Off `
            -IncludeRule Local/FragmentRule -Output Object -NoSummary)
        $Preview = @(Start-Nitpicking -Script $Fixture.FragmentAst -FixMode Preview `
            -IncludeRule Local/FragmentRule -Output Object -NoSummary)
        $Original = ($Preview | Where-Object {
            $_.GetType().Name -eq 'NitpickCorrectionResult'
        }).Proposal.OriginalFindings[0]

        $Off | Should -HaveCount 1
        $Off[0].ViolationExtent.File | Should -BeExactly $Original.ViolationExtent.File
        $Off[0].ViolationExtent.StartOffset | Should -Be $Original.ViolationExtent.StartOffset
        $Off[0].ViolationExtent.EndOffset | Should -Be $Original.ViolationExtent.EndOffset
        $Off[0].ViolationExtent.StartLineNumber | Should -Be $Original.ViolationExtent.StartLineNumber
        $Off[0].ViolationExtent.StartColumnNumber | Should -Be $Original.ViolationExtent.StartColumnNumber
    }

    It 'returns only fragment text for NoChanges' {
        $Fixture = New-TestSourceDocument -Kind Nested -Source '$Value = 200'
        $Output = @(Start-Nitpicking -Script $Fixture.FragmentAst -FixMode Apply `
            -IncludeRule Local/FragmentRule -Output Object -NoSummary)
        $Result = $Output | Where-Object { $_.GetType().Name -eq 'NitpickCorrectionResult' }

        $Result.Proposal.Status | Should -Be 'NoChanges'
        $Result.Report.EffectiveText | Should -BeExactly '{$Value = 200}'
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
    }

    It 'returns original fragment text when a correction cannot relocate the fragment' {
        $Finding = New-NitpickFinding `
            -RuleId Local/ReplaceFragment `
            -Message 'Change node type' `
            -ViolationExtent $Fixture.Document.Ast.Extent `
            -Severity Information `
            -Explanation 'Invalid shape.' `
            -ScriptPath $Fixture.Path `
            -Corrections (New-NitpickCorrection `
                -ViolationExtent $Fixture.Document.Ast.Extent `
                -ReplacementText "'a string'" `
                -FilePathOrContext $Fixture.Path `
                -Description 'Different node type'
            )

        $Result = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture; Finding = $Finding } {
            param($Fixture, $Finding)
            Resolve-NitpickTargetCorrection `
                -Document $Fixture.Document `
                -Finding $Finding `
                -Rule @() `
                -FixMode Apply
        }

        $Result.Proposal.Status | Should -Be 'FailedValidation'
        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Proposal.ParseErrors[0].ErrorId | Should -Be 'FragmentNotFound'
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 0
        $Result.Report.EffectiveText | Should -BeExactly '{$Value = 1}'
    }

    It 'rejects all selected corrections when one edit reaches outside the fragment' {
        $Inside = New-AstTextEdit `
            -Extent $Fixture.Document.Ast.EndBlock.Statements[0].Extent `
            -ReplacementText '$Value = 200' `
            -Reason 'Inside'

        $Outside = New-AstTextEdit `
            -Extent $Fixture.Document.Root.Ast.EndBlock.Statements[0].Extent `
            -ReplacementText '$Value = 300' `
            -Reason 'Outside'

        $Finding = New-NitpickFinding `
            -RuleId Local/Outside -Message 'Outside edit' `
            -ViolationExtent $Fixture.Document.Ast.Extent `
            -Severity Information `
            -Explanation 'Outside batch.' `
            -ScriptPath $Fixture.Path `
            -Corrections (New-NitpickCorrection `
                -TextEdit @($Inside, $Outside) `
                -FilePathOrContext $Fixture.Path `
                -Description 'Invalid batch'
            )

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Fixture.Document `
            -Finding $Finding `
            -Rule (Get-Nitpick -Id Local/FragmentRule)

        $Proposal.Status | Should -Be 'Rejected'
        $Proposal.WasReanalyzed | Should -BeFalse
        $Proposal.AcceptedCorrections | Should -HaveCount 0
        $Proposal.Document.Edits | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount 1
        $Proposal.SkippedCorrections[0].Reason | Should -Match 'outside the submitted fragment'
        $Proposal.CandidateText | Should -BeExactly $Fixture.FileText
    }

    It 'keeps the annotation above a bare path with native hyperlinks disabled' -ForEach @(
        @{ FixMode = 'Off' }
        @{ FixMode = 'Preview' }
    ) {
        $PreviousForce = $env:FORCE_HYPERLINK
        $PreviousNo = $env:NO_HYPERLINK
        try {
            $env:FORCE_HYPERLINK = '0'
            $env:NO_HYPERLINK = '1'
            $Text = (Start-Nitpicking `
                -Script $Fixture.FragmentAst `
                -FixMode $FixMode `
                -IncludeRule Local/FragmentRule `
                -Output Text `
                -NoSummary
            ) -join "`n"
        } finally {
            $env:FORCE_HYPERLINK = $PreviousForce
            $env:NO_HYPERLINK = $PreviousNo
        }

        $Lines = $Text -split '\r?\n'
        $Lines[0] | Should -BeExactly '(fragment, lines 2-2)'
        $Lines[1] | Should -BeExactly $Fixture.Path
        $Lines[2] | Should -Match '^  2:4'
        $Text.Contains("$([char]27)]8;;") | Should -BeFalse
    }

    It 'keeps candidate position hyperlinks source-absolute when OSC 8 is forced' {
        $Previous = $env:FORCE_HYPERLINK
        try {
            $env:FORCE_HYPERLINK = '1'
            $Text = (Start-Nitpicking `
                -Script $Fixture.FragmentAst `
                -FixMode Preview `
                -IncludeRule Local/FragmentRule `
                -Output Text `
                -NoSummary
            ) -join "`n"
        } finally {
            $env:FORCE_HYPERLINK = $Previous
        }

        $Uri = [Uri]::new($Fixture.Path).AbsoluteUri
        $Text | Should -Match ([regex]::Escape("$Uri#2:4"))
    }

    It 'does not apply path filters or rule path predicates to explicitly submitted fragments' {
        $Rule = Get-Nitpick -Id Local/FragmentRule
        $Rule.IncludePath = @('*not-this-file.ps1')
        $Rule.ExcludePath = @('*')
        $Output = @(Start-Nitpicking `
            -Script $Fixture.FragmentAst `
            -FixMode Off `
            -IncludeRule Local/FragmentRule `
            -IncludePath '*not-this-file.ps1' `
            -ExcludePath '*' `
            -Output Object `
            -NoSummary
        )

        $Output | Should -HaveCount 1
        $Output[0].RuleId | Should -BeExactly Local/FragmentRule
    }
}
