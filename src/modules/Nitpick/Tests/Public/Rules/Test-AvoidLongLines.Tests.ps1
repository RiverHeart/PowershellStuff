using namespace System.Collections
using namespace System.Management.Automation.Language
using module AstEditor

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'AvoidLongLines' {
    It 'passes at the limit and reports one detection-only warning above it' {
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines
        $AtLimit = New-AstDocument -InputObject ('x' * 120)
        $AboveLimit = New-AstDocument -InputObject ('x' * 121)

        @($Rule.Invoke($AtLimit)) | Should -HaveCount 0
        $Findings = @($Rule.Invoke($AboveLimit))
        $Findings | Should -HaveCount 1
        $Findings[0].Severity | Should -BeExactly 'Warning'
        $Findings[0].ViolationExtent.Text.Length | Should -Be 121
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'uses the default and validates direct settings overrides' {
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines
        $Document = New-AstDocument -InputObject 'four'

        @($Rule.Invoke($Document)) | Should -HaveCount 0
        $OverrideFindings = @($Rule.Invoke($Document, @{
            RuleSettings = @{ MaximumLength = [int16] 3 }
        }))
        $OverrideFindings | Should -HaveCount 1
        $OverrideFindings[0].Message | Should -BeExactly 'Line has 4 UTF-16 code units; maximum is 3.'

        {
            $Rule.Invoke($Document, @{ RuleSettings = @{ MaximumLength = $false } })
        } | Should -Throw -ErrorId 'NitpickInvalidRuleSettings*'
    }

    It 'counts tabs, surrogate pairs, and trailing spaces as written' {
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines
        $Sources = @(
            ('x' * 120) + "`t"
            ('x' * 119) + [char]::ConvertFromUtf32(0x1F600)
            ('x' * 120) + ' '
        )

        foreach ($Source in $Sources) {
            @($Rule.Invoke((New-AstDocument -InputObject $Source))) | Should -HaveCount 1
        }
    }

    It 'excludes LF, CRLF, and CR terminators and checks a final unterminated line' -ForEach @(
        @{ NewLine = "`n" }
        @{ NewLine = "`r`n" }
        @{ NewLine = "`r" }
    ) {
        $Source = ('x' * 120) + $NewLine + $NewLine + ('y' * 121)
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines
        $Findings = @($Rule.Invoke((New-AstDocument -InputObject $Source)))

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 3
        $Findings[0].ViolationExtent.Text.Length | Should -Be 121
    }

    It 'checks comments and multiline string content without AST filtering' {
        $Source = @(
            '#' + ('c' * 120)
            '$Text = "'
            ('s' * 121)
            '"'
            '$Here = @'''
            ('h' * 121)
            '''@'
        ) -join "`n"
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines

        $Findings = @($Rule.Invoke((New-AstDocument -InputObject $Source)))

        $Findings | Should -HaveCount 3
        $Findings.ViolationExtent.StartLineNumber | Should -Be @(1, 3, 6)
    }

    It 'preserves standalone diagnostic output conventions' {
        $Ast = [Parser]::ParseInput(('x' * 121), [ref] $null, [ref] $null)

        $Findings = @(Test-AvoidLongLines -ScriptBlockAst $Ast)

        $Findings | Should -HaveCount 1
        $Findings[0].GetType().Name | Should -BeExactly 'DiagnosticRecord'
        $Findings[0].Extent.StartColumnNumber | Should -Be 1
        $Findings[0].SuggestedCorrections | Should -BeNullOrEmpty
    }

    It 'anchors a partial physical line finding inside the submitted fragment' {
        $Path = Join-Path $TestDrive 'LongFragment.ps1'
        $Source = '$Before = 1; & { $Value = 2 }; $After = 3'
        $Root = [Parser]::ParseInput($Source, $Path, [ref] $null, [ref] $null)
        $Fragment = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Document = New-AstDocument -InputObject $Fragment
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines -Settings @{
            MaximumLength = @{ Type = 'Integer'; Default = 10; Minimum = 1 }
        }

        $Findings = @($Rule.Invoke($Document))

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.StartOffset |
            Should -BeGreaterOrEqual $Document.Ast.Extent.StartOffset
        $Findings[0].ViolationExtent.EndOffset |
            Should -BeLessOrEqual $Document.Ast.Extent.EndOffset
        $Findings[0].ViolationExtent.File | Should -BeExactly $Path
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 1
        $Findings[0].Message | Should -Match 'Line has 41 UTF-16 code units'
    }

    It 'is selected by default and respects whole-target suppression' {
        $LongComment = '#' + ('x' * 121)
        $DefaultResults = @(
            Start-Nitpicking -Script $LongComment -Output Object -NoSummary -ErrorAction Stop
        )
        @($DefaultResults | Where-Object RuleId -eq 'Nitpick/AvoidLongLines') |
            Should -HaveCount 1

        $Suppressed = @(
            Start-Nitpicking `
                -Script "# nitpick disable-target Nitpick/AvoidLongLines`n$LongComment" `
                -IncludeRule Nitpick/AvoidLongLines `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
        )
        @($Suppressed | Where-Object RuleId -eq 'Nitpick/AvoidLongLines') |
            Should -HaveCount 0

        $NextLineSuppressed = @(
            Start-Nitpicking `
                -Script "# nitpick disable-next-line Nitpick/AvoidLongLines`n$LongComment" `
                -IncludeRule Nitpick/AvoidLongLines `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
        )
        @($NextLineSuppressed | Where-Object RuleId -eq 'Nitpick/AvoidLongLines') |
            Should -HaveCount 0

        $Excluded = @(
            Start-Nitpicking `
                -Script $LongComment `
                -ExcludeRule Nitpick/AvoidLongLines `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
        )
        @($Excluded | Where-Object RuleId -eq 'Nitpick/AvoidLongLines') |
            Should -HaveCount 0
    }

    It 'uses per-rule settings during direct correction reanalysis' {
        $Rule = New-Nitpick -Callable Measure-AvoidLongLines
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Script 'four' `
            -Finding @() `
            -Rule $Rule `
            -RuleSettings @{ 'Nitpick/AvoidLongLines' = @{ MaximumLength = 3 } }

        $Proposal.WasReanalyzed | Should -BeTrue
        $Proposal.CandidateFindings | Should -HaveCount 1
        $Proposal.CandidateFindings[0].Message |
            Should -BeExactly 'Line has 4 UTF-16 code units; maximum is 3.'
    }

    It 'propagates project settings through original and candidate analysis' {
        $ConfigurationPath = Join-Path $TestDrive 'line-settings.psd1'
        Set-Content -LiteralPath $ConfigurationPath -Value @'
@{
    Rules = @{
        'Nitpick/AvoidLongLines' = @{ MaximumLength = 3 }
    }
}
'@

        $Results = @(
            Start-Nitpicking `
                -Script 'four' `
                -ConfigurationPath $ConfigurationPath `
                -IncludeRule Nitpick/AvoidLongLines `
                -FixMode Preview `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
        )
        $Finding = $Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' }
        $CorrectionResult = $Results |
            Where-Object { $_.PSTypeNames -contains 'NitpickCorrectionResult' }

        $Finding | Should -HaveCount 1
        $Finding[0].Message | Should -BeExactly 'Line has 4 UTF-16 code units; maximum is 3.'
        $CorrectionResult.Proposal.WasReanalyzed | Should -BeTrue
        $CorrectionResult.Report.EffectiveFindings | Should -HaveCount 1
        $CorrectionResult.Report.EffectiveFindings[0].Message |
            Should -BeExactly 'Line has 4 UTF-16 code units; maximum is 3.'
    }

    It 'trims the 118-unit plus three-space case only when the whitespace rule is selected' {
        $Source = ('#' + ('x' * 117) + '   ')
        $Document = New-AstDocument -InputObject $Source
        $LongLines = New-Nitpick -Callable Measure-AvoidLongLines
        $TrailingWhitespace = New-Nitpick -Callable Measure-AvoidTrailingWhitespace

        $Both = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($LongLines.Invoke($Document) + $TrailingWhitespace.Invoke($Document)) `
            -Rule @($LongLines, $TrailingWhitespace) `
            -RuleSettings @{
                'Nitpick/AvoidLongLines' = @{}
                'Nitpick/AvoidTrailingWhitespace' = @{}
            }

        $Both.OriginalFindings | Should -HaveCount 2
        $Both.CandidateText | Should -BeExactly ('#' + ('x' * 117))
        $Both.CandidateFindings | Should -HaveCount 0

        $ReversedDocument = New-AstDocument -InputObject $Source
        $Reversed = Resolve-NitpickCorrectionProposal `
            -Document $ReversedDocument `
            -Finding @(
                $TrailingWhitespace.Invoke($ReversedDocument) +
                $LongLines.Invoke($ReversedDocument)
            ) `
            -Rule @($TrailingWhitespace, $LongLines) `
            -RuleSettings @{
                'Nitpick/AvoidTrailingWhitespace' = @{}
                'Nitpick/AvoidLongLines' = @{}
            }

        $Reversed.CandidateText | Should -BeExactly $Both.CandidateText
        $Reversed.CandidateFindings | Should -HaveCount 0

        $UntrimmedDocument = New-AstDocument -InputObject $Source
        $OnlyLongLines = Resolve-NitpickCorrectionProposal `
            -Document $UntrimmedDocument `
            -Finding @($LongLines.Invoke($UntrimmedDocument)) `
            -Rule $LongLines `
            -RuleSettings @{ 'Nitpick/AvoidLongLines' = @{} }

        $OnlyLongLines.CandidateText | Should -BeExactly $Source
        $OnlyLongLines.CandidateFindings | Should -HaveCount 1
        $OnlyLongLines.CandidateFindings[0].RuleId | Should -BeExactly 'Nitpick/AvoidLongLines'
    }

    It 'reports original findings when the whitespace correction cannot be written' {
        $Source = '#' + ('x' * 117) + '   '
        $Path = Join-Path $TestDrive 'FailedLongLineWrite.ps1'
        [IO.File]::WriteAllText($Path, $Source)
        Mock Save-AstDocument -ModuleName Nitpick {
            [pscustomobject]@{
                WriteStatus = 'FailedWrite'
                WasWritten = $false
                ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [IO.IOException]::new('Simulated write failure.'),
                    'TestWriteFailure',
                    [System.Management.Automation.ErrorCategory]::WriteError,
                    $null
                )
            }
        }

        $Results = @(
            Start-Nitpicking `
                -Path $Path `
                -IncludeRule Nitpick/AvoidLongLines,Nitpick/AvoidTrailingWhitespace `
                -FixMode Apply `
                -Output Object `
                -NoSummary `
                -Confirm:$false `
                -ErrorAction SilentlyContinue
        )

        $CorrectionResult = $Results |
            Where-Object { $_.PSTypeNames -contains 'NitpickCorrectionResult' }

        $CorrectionResult.Application.Status | Should -BeExactly 'FailedWrite'
        $CorrectionResult.Proposal.CandidateText | Should -BeExactly ('#' + ('x' * 117))
        $CorrectionResult.Report.EffectiveText | Should -BeExactly $Source
        $CorrectionResult.Report.EffectiveFindings | Should -HaveCount 2
        $CorrectionResult.Report.EffectiveFindings.RuleId |
            Should -Contain 'Nitpick/AvoidLongLines'
    }
}
