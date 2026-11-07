using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    function Get-TestLineSuppression {
        param ([string] $Source)
        InModuleScope Nitpick -Parameters @{ Source = $Source } {
            param($Source)
            Get-NitpickSuppression -Document (New-AstDocument -InputObject $Source)
        }
    }

    function New-TestLineHeaderFinding {
        param ($Document, [string] $Replacement)

        $Comment = @($Document.Tokens | Where-Object Kind -eq Comment)[0]
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Comment.Extent `
            -ReplacementText $Replacement `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Rewrite the suppression comment.'

        New-NitpickFinding `
            -RuleId Local/Header `
            -Message 'Rewrite the suppression comment.' `
            -ViolationExtent $Comment.Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises snapshot-specific line suppression.' `
            -Corrections $Correction
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Line suppression grammar' {
    It 'parses physical-line selectors: <Source>' -ForEach @(
        @{ Source = '# nitpick disable-line Nitpick/*'; Line = 1; Count = 1 }
        @{ Source = '$Value = 1 # NITPICK DISABLE-LINE Nitpick/*, */Other Local/Unknown -- reason, text'; Line = 1; Count = 3 }
        @{ Source = "# comment`r`n# nitpick disable-next-line *"; Line = 3; Count = 1 }
        @{ Source = "# comment`n# NiTpIcK DISABLE-NEXT-LINE Nitpick/* --"; Line = 3; Count = 1 }
    ) {
        $Result = Get-TestLineSuppression $Source
        $Result.Selectors | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 0
        $Result.LineSelectors[$Line] | Should -HaveCount $Count
    }

    It 'unions selectors from directives covering the same physical line' {
        $Result = Get-TestLineSuppression "# nitpick disable-next-line Owner/*`n`$Value = 1 # nitpick disable-line Other/*"
        $Result.LineSelectors[2] | Should -HaveCount 2
        $Result.LineSelectors[2] | Should -Contain 'Owner/*'
        $Result.LineSelectors[2] | Should -Contain 'Other/*'
    }

    It 'ignores the entire malformed directive: <Source>' -ForEach @(
        @{ Source = '# nitpick disable-line' }
        @{ Source = '# nitpick disable-next-line' }
        @{ Source = '# nitpick disable-line Nitpick/*,' }
        @{ Source = '# nitpick disable-next-line Nitpick/*, ,Other/*' }
        @{ Source = '# nitpick disable-line Nitpick/* BareName' }
        @{ Source = '# nitpick disable-next-line Nitpick/[' }
        @{ Source = '$Value = 1 # nitpick disable-next-line *' }
        @{ Source = '<# comment #> # nitpick disable-next-line *' }
    ) {
        $Result = Get-TestLineSuppression $Source
        $Result.LineSelectors.Count | Should -Be 0
        $Result.Diagnostics | Should -HaveCount 1
        $Result.Diagnostics[0].ViolationExtent.StartLineNumber | Should -Be 1
    }

    It 'does not interpret literal string or block-comment text: <Source>' -ForEach @(
        @{ Source = "'# nitpick disable-line *'" }
        @{ Source = '"# nitpick disable-next-line *"' }
        @{ Source = "@'`n# nitpick disable-next-line *`n'@" }
        @{ Source = "@`"`n# nitpick disable-line *`n`"@" }
        @{ Source = "<#`n# nitpick disable-next-line *`n#>" }
    ) {
        $Result = Get-TestLineSuppression $Source
        $Result.LineSelectors.Count | Should -Be 0
        $Result.Diagnostics | Should -HaveCount 0
    }

    It 'recognizes actual comments nested in an expandable-string subexpression' {
        #=== Arrange ===#
        $Source = '"$(' + "`n# nitpick disable-next-line Nitpick/*`n-not (`$Value -is [int])`n)" + '"'

        #=== Act ===#
        $Result = Get-TestLineSuppression $Source
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Result.LineSelectors[3] | Should -HaveCount 1
        $Result.Diagnostics | Should -HaveCount 0
        $Findings | Should -HaveCount 0
    }
}

Describe 'Line suppression analysis and corrections' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'filters same-line findings before counts and thresholds in <FixMode>' -ForEach @(
        @{ FixMode = 'Off' }
        @{ FixMode = 'Preview' }
        @{ FixMode = 'Apply' }
    ) {
        #=== Arrange ===#
        $Source = '-not ($First -is [int]); -not ($Second -is [int]) # nitpick disable-line nitpick/useisnotoperator'

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode $FixMode `
            -Output Object `
            -ErrorOn Information `
            -ErrorAction Stop
        )

        #=== Assert ===#
        @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' }) |
            Should -HaveCount 0

        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        $Summary.InformationCount | Should -Be 0
        $Summary.CorrectedFindingCount | Should -Be 0
        $Summary.SkippedFindingCount | Should -Be 0
        if ($FixMode -ne 'Off') {
            $Result = $Results | Where-Object { $_.GetType().Name -eq 'NitpickCorrectionResult' }
            $Result.Report.EffectiveText | Should -BeExactly $Source
            $Result.Proposal.OriginalFindings | Should -HaveCount 0
            $Result.Proposal.CandidateFindings | Should -HaveCount 0
            $Result.Proposal.AcceptedCorrections | Should -HaveCount 0
        }
    }

    It 'suppresses a standalone disable-line comment finding without skipping its producer' {
        #=== Arrange ===#
        $Source = "# nitpick disable-line Nitpick/AvoidTrailingWhitespace   `n`$Value = 1"

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/AvoidTrailingWhitespace `
            -Output Object `
            -NoSummary `
            -ErrorOn Information `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Results | Should -HaveCount 0

        # A document rule reports comment whitespace on the directive's own line.
        $Rule = New-Nitpick -Callable Measure-AvoidTrailingWhitespace
        @($Rule.Invoke((New-AstDocument -InputObject $Source))) | Should -HaveCount 1
    }

    It 'executes line-suppressed producers in both original and candidate analysis' {
        #=== Arrange ===#
        $Calls = [System.Collections.Generic.List[object]]::new()
        $Callable = {
            param([ScriptBlockAst] $ScriptBlockAst)

            $Calls.Add($ScriptBlockAst)
            New-NitpickFinding `
                -RuleId Local/Observed `
                -Message 'The producer executed.' `
                -ViolationExtent $ScriptBlockAst.EndBlock.Statements[0].Extent `
                -Severity Warning `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Observe dispatch.'
        }.GetNewClosure()

        Register-Nitpick -Name Observed -Source Tests -Callable $Callable

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script "# nitpick disable-next-line Local/*`n`$Value = 1" `
            -IncludeRule Local/Observed `
            -FixMode Preview `
            -Output Object `
            -ErrorOn Warning `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Calls | Should -HaveCount 2
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.FindingCount | Should -Be 0
        $Summary.WarningCount | Should -Be 0
    }

    It 'uses the immediately following physical line, not the next statement: <Label>' -ForEach @(
        @{ Label = 'statement'; Between = ''; Count = 0 }
        @{ Label = 'blank'; Between = "`n"; Count = 1 }
        @{ Label = 'comment'; Between = "# ordinary`n"; Count = 1 }
    ) {
        #=== Arrange ===#
        $Source = "# nitpick disable-next-line Nitpick/*`n$Between-not (`$Value -is [int])"

        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount $Count
    }

    It 'does not suppress a multiline finding anchored before a suppressed line' {
        #=== Arrange ===#
        $Source = "-not (`n`$Value -is [int]) # nitpick disable-line Nitpick/*"

        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 1
        $Findings[0].ViolationExtent.EndLineNumber | Should -Be 2
    }

    It 'suppresses the entire multiline finding when its start line is suppressed' {
        #=== Arrange ===#
        $Source = "# nitpick disable-next-line Nitpick/*`n-not (`n`$Value -is [int])"

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Apply `
            -Output Object `
            -NoSummary `
            -ErrorOn Information `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Results | Should -HaveCount 1
        $Results[0].Proposal.AcceptedCorrections | Should -HaveCount 0
        $Results[0].Report.EffectiveText | Should -BeExactly $Source
    }

    It 'matches attributed owning RuleIds without suppressing another namespace' {
        #=== Arrange ===#
        Register-Nitpick -Callable Test-UseIsNotOperator -Namespace Owner
        Register-Nitpick -Callable Test-UseIsNotOperator -Namespace Other

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script '-not ($Value -is [int]) # nitpick disable-line owner/*' `
            -ExcludeDefaults `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Results | Should -HaveCount 1
        $Results[0].RuleId | Should -Be Other/UseIsNotOperator
    }

    It 'allows an unmatched selector without suppressing unrelated findings' {
        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script '-not ($Value -is [int]) # nitpick disable-line Missing/Rule' `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be Nitpick/UseIsNotOperator
    }

    It 'does not infer native suppression identity from external records' {
        #=== Arrange ===#
        Register-Nitpick -Name External -Source Tests -Callable {
            param([ScriptBlockAst] $ScriptBlockAst)
            [pscustomobject]@{
                RuleId = 'Local/External'
                RuleName = 'External'
                Message = 'Non-native output.'
                Severity = 'Information'
                ViolationExtent = $ScriptBlockAst.Extent
            }
        }

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script '# nitpick disable-line *' `
            -IncludeRule Local/External `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Results | Should -HaveCount 1
        $Results[0].Message | Should -Be 'Non-native output.'
    }

    It 'keeps diagnostics unsuppressible even when their line is covered by all-rules selectors' {
        #=== Arrange ===#
        $Source = "# nitpick disable-next-line *`n# nitpick disable-line Invalid"

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Preview `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        $Diagnostic = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })

        #=== Assert ===#
        $Diagnostic | Should -HaveCount 1
        $Diagnostic[0].RuleId | Should -Be Nitpick/InvalidSuppressionDirective
        $Diagnostic[0].ViolationExtent.StartLineNumber | Should -Be 2
        { Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -ErrorOn Warning -Output Object `
            -ErrorAction Stop
        } | Should -Throw "*'Warning'*"

        $Path = Join-Path $TestDrive 'InvalidSyntax.ps1'
        [IO.File]::WriteAllText($Path, "# nitpick disable-next-line *`nif ( # nitpick disable-line *")

        $Results = @(Start-Nitpicking `
            -Path $Path `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction SilentlyContinue
        )

        @($Results | Where-Object RuleId -eq 'Nitpick/PowerShellParseError').Count |
            Should -BeGreaterThan 0
    }

    It 'does not turn target suppression back on or validate invalid invocation selectors' {
        $Source = "# nitpick disable-target Nitpick/*`n# nitpick disable-next-line Missing/*`n-not (`$Value -is [int])"
        @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorOn Information `
            -ErrorAction Stop
        ) | Should -HaveCount 0

        { Start-Nitpicking `
            -Script '# nitpick disable-line *' `
            -IncludeRule Missing/Rule `
            -ErrorAction Stop
        } | Should -Throw '*No Nitpick rules match*'
    }

    It 'keeps files independent and applies only unsuppressed complete fixes' {
        #=== Arrange ===#
        $Suppressed = Join-Path $TestDrive 'Suppressed.ps1'
        $Active = Join-Path $TestDrive 'Active.ps1'
        $Source = '-not ($Value -is [int]) # nitpick disable-line Nitpick/*'
        [IO.File]::WriteAllText($Suppressed, $Source)
        [IO.File]::WriteAllText($Active, '-not ($Value -is [int])')

        #=== Act ===#
        $Results = @(@($Suppressed, $Active) | Start-Nitpicking `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Apply `
            -Output Object `
            -ErrorAction Stop
        )

        #=== Assert ===#
        [IO.File]::ReadAllText($Suppressed) | Should -BeExactly $Source
        [IO.File]::ReadAllText($Active) | Should -BeExactly ' ($Value -isnot [int])'
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.FindingCount | Should -Be 1
        $Summary.CorrectedFindingCount | Should -Be 1
        $Summary.TargetCount | Should -Be 2
    }

    It 'omits suppressed findings from text output' {
        Mock Write-Host -ModuleName Nitpick {}
        @(Start-Nitpicking `
            -Script '-not ($Value -is [int]) # nitpick disable-line *' `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Text `
            -NoSummary `
            -ErrorAction Stop
        ) | Should -HaveCount 0
    }

    It 'retains snapshot coordinates and ignores comments outside a fragment with <NewLineName>' -ForEach @(
        @{ NewLineName = 'LF'; NewLine = "`n" }
        @{ NewLineName = 'CRLF'; NewLine = "`r`n" }
    ) {
        #=== Arrange ===#
        $Source = @(
            '# nitpick disable-next-line *'
            '& { -not ($First -is [int])'
            '  # nitpick disable-next-line Nitpick/*'
            '  -not ($Second -is [int])'
            '  & { -not ($Third -is [int]) # nitpick disable-line Nitpick/*'
            '  }'
            '}'
        ) -join $NewLine

        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseInput($Source, 'Fragment.ps1', [ref] $Tokens, [ref] $Errors)

        $Nested = $Root.Find({
            param($Node)

            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script $Nested `
            -FixMode Preview `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        $Proposal = ($Results | Where-Object {
            $_.GetType().Name -eq 'NitpickCorrectionResult'
        }).Proposal

        #=== Assert ===#
        $Proposal.OriginalFindings | Should -HaveCount 1
        $Proposal.OriginalFindings[0].ViolationExtent.StartLineNumber | Should -Be 2
        $Proposal.OriginalFindings[0].ViolationExtent.File | Should -BeExactly 'Fragment.ps1'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.CandidateFindings | Should -HaveCount 0
    }
}

Describe 'Line suppression in direct correction proposals' {
    BeforeEach {
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
    }

    It 'filters whole corrections before guided selection with <InputKind>' -ForEach @(
        @{ InputKind = 'Document' }
        @{ InputKind = 'Script' }
    ) {
        #=== Arrange ===#
        $Source = "-not (`$First -is [int]) # nitpick disable-line Nitpick/*`n-not (`$Second -is [int])"
        $Document = New-AstDocument -InputObject $Source

        #=== Act ===#
        $Findings = @($Rule.Invoke($Document))
        $Corrections = $Findings[0].Corrections
        $Edits = $Corrections[0].TextEdits

        #=== Assert ===#
        $Edits | Should -HaveCount 2
        $Corrections[0].Applicability = 'Review'

        $InputParameters = if ($InputKind -eq 'Document') {
            @{ Document = $Document }
        } else {
            @{ Script = $Source }
        }

        $Proposal = Resolve-NitpickCorrectionProposal `
            @InputParameters `
            -Finding $Findings `
            -Rule $Rule `
            -CorrectionSelector {
                throw 'Suppressed corrections must not reach guided selection.'
            }

        $Proposal.OriginalFindings | Should -HaveCount 1
        $Proposal.CandidateFindings | Should -HaveCount 0
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.SkippedCorrections | Should -HaveCount 1
        $Proposal.SkippedCorrections[0].Reason | Should -BeLike '*suppressed*disable-line*'
        $Proposal.UndecidedFindings | Should -HaveCount 0
        $Proposal.SkippedFindings | Should -HaveCount 0
        $Proposal.CandidateText.StartsWith('-not ($First -is [int])') | Should -BeTrue
        $Proposal.CandidateText | Should -Match '\$Second -isnot'

        [object]::ReferenceEquals($Corrections, $Findings[0].Corrections) | Should -BeTrue
        [object]::ReferenceEquals($Edits, $Findings[0].Corrections[0].TextEdits) | Should -BeTrue
    }

    It 'recomputes candidate physical-line suppression when an edit <Label> a directive' -ForEach @(
        @{ Label = 'removes'; Original = '# nitpick disable-next-line Nitpick/*'; Replacement = '# ordinary'; OriginalCount = 2; CandidateCount = 2 }
        @{ Label = 'adds'; Original = '# ordinary'; Replacement = '# nitpick disable-next-line Nitpick/*'; OriginalCount = 3; CandidateCount = 1 }
        @{ Label = 'moves away from code'; Original = '# nitpick disable-next-line Nitpick/*'; Replacement = "# nitpick disable-next-line Nitpick/*`n"; OriginalCount = 2; CandidateCount = 2 }
        @{ Label = 'malforms'; Original = '# nitpick disable-next-line Nitpick/*'; Replacement = '# nitpick disable-next-line Invalid'; OriginalCount = 2; CandidateCount = 3 }
    ) {
        #=== Arrange ===#
        $Document = New-AstDocument -InputObject "$Original`n-not (`$First -is [int])`n-not (`$Second -is [int])"
        $Header = New-TestLineHeaderFinding -Document $Document -Replacement $Replacement
        $Native = @($Rule.Invoke($Document))
        foreach ($Finding in $Native) { $Finding.Corrections[0].Applicability = 'Review' }

        #=== Act ===#
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($Header; $Native) `
            -Rule $Rule

        #=== Assert ===#
        $Proposal.OriginalFindings | Should -HaveCount $OriginalCount
        $Proposal.CandidateFindings | Should -HaveCount $CandidateCount
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.WasReanalyzed | Should -BeTrue
    }

    It 'does not treat a suppressed line as an edit-protection range' {
        #=== Arrange ===#
        $Document = New-AstDocument `
            -InputObject "`$Value = 1`n-not (`$Value -is [int]) # nitpick disable-line *"

        #=== Act ===#
        $Finding = New-NitpickFinding `
            -RuleId Local/Rewrite `
            -Message 'Rewrite snapshot.' `
            -ViolationExtent $Document.Ast.EndBlock.Statements[0].Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'A finding on line 1 may edit line 2.' `
            -Corrections (New-NitpickCorrection `
                -ViolationExtent $Document.Ast.Extent `
                -ReplacementText '$Value = 2' `
                -FilePathOrContext '<ScriptBlock>' `
                -Description 'Replace both lines.'
            )

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($Finding)

        #=== Assert ===#
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.CandidateText | Should -BeExactly '$Value = 2'
    }

    It 'recomputes trailing disable-line directives when an edit <Label> one' -ForEach @(
        @{ Label = 'removes'; Original = '# nitpick disable-line Nitpick/*'; Replacement = '# ordinary'; OriginalCount = 1; CandidateCount = 1 }
        @{ Label = 'adds'; Original = '# ordinary'; Replacement = '# nitpick disable-line Nitpick/*'; OriginalCount = 2; CandidateCount = 0 }
    ) {
        #=== Arrange ===#
        $Document = New-AstDocument -InputObject "-not (`$Value -is [int]) $Original"
        $Header = New-TestLineHeaderFinding -Document $Document -Replacement $Replacement

        #=== Act ===#
        $Native = @($Rule.Invoke($Document))
        $Native[0].Corrections[0].Applicability = 'Review'
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($Header; $Native) `
            -Rule $Rule

        #=== Assert ===#
        $Proposal.OriginalFindings | Should -HaveCount $OriginalCount
        $Proposal.CandidateFindings | Should -HaveCount $CandidateCount
        $Proposal.AcceptedCorrections | Should -HaveCount 1
    }

    It 'preserves line suppression after earlier fragment edits shift snapshot coordinates' {
        #=== Arrange ===#
        $Source = "`$Prefix = 1; & {`r`n# ordinary`r`n# nitpick disable-next-line Nitpick/*`r`n-not (`$Value -is [int])`r`n}"
        $Tokens = $null
        $Errors = $null

        $Root = [Parser]::ParseInput($Source, 'ShiftedFragment.ps1', [ref] $Tokens, [ref] $Errors)
        $Nested = $Root.Find({
            param($Node)

            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Document = New-AstDocument -InputObject $Nested
        $Header = New-TestLineHeaderFinding -Document $Document -Replacement "# ordinary`r`n# extra line"

        #=== Act ===#
        $Native = @($Rule.Invoke($Document))
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($Header; $Native) `
            -Rule $Rule

        #=== Assert ===#
        $Native[0].ViolationExtent.StartLineNumber | Should -Be 4

        $Proposal.OriginalFindings | Should -HaveCount 1
        $Proposal.CandidateFindings | Should -HaveCount 0
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.CandidateText | Should -Match '# extra line'
        $Proposal.CandidateText | Should -Match '\-not \(\$Value -is \[int\]\)'
        $Proposal.SourcePath | Should -BeExactly 'ShiftedFragment.ps1'
    }

    It 'retains original and candidate suppression facts when a write is <Outcome>' -ForEach @(
        @{ Outcome = 'declined'; Status = 'Declined'; CandidateReport = $false }
        @{ Outcome = 'WhatIf'; Status = 'WhatIf'; CandidateReport = $true }
        @{ Outcome = 'failed'; Status = 'FailedWrite'; CandidateReport = $false }
    ) {
        #=== Arrange ===#
        $Path = Join-Path $TestDrive 'Application.ps1'
        $Source = "# nitpick disable-next-line Nitpick/*`n-not (`$Value -is [int])"
        [IO.File]::WriteAllText($Path, $Source)
        $Document = New-AstDocument -Path $Path
        $Header = New-TestLineHeaderFinding -Document $Document -Replacement '# ordinary'

        #=== Act ===#
        $Native = @($Rule.Invoke($Document))

        if ($Outcome -eq 'failed') {
            Mock Should-Process -ModuleName Nitpick { $true }
            Mock Save-AstDocument -ModuleName Nitpick {
                [pscustomobject]@{
                    WriteStatus = 'FailedWrite'
                    WasWritten = $false
                    ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [IO.IOException]::new('Simulated write failure.'),
                        'TestWriteFailure',
                        [System.Management.Automation.ErrorCategory]::WriteError, $null
                    )
                }
            }
        } else {
            Mock Should-Process -ModuleName Nitpick { $false }
        }

        $Result = InModuleScope Nitpick -Parameters @{
            Document = $Document
            Header = $Header
            Native = $Native
            Rule = $Rule
            Outcome = $Outcome
        } {
            param($Document, $Header, $Native, $Rule, $Outcome)

            Resolve-NitpickTargetCorrection `
                -Document $Document `
                -Finding @($Header; $Native) `
                -Rule $Rule `
                -FixMode Apply `
                -WhatIf:($Outcome -eq 'WhatIf')
        }

        #=== Assert ===#
        $Result.Application.Status | Should -Be $Status
        $Result.Proposal.OriginalFindings | Should -HaveCount 1
        $Result.Proposal.OriginalFindings[0].RuleId | Should -Be Local/Header
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
        $Result.Proposal.CandidateFindings[0].RuleId | Should -Be Nitpick/UseIsNotOperator
        $Result.Report.AnalysisSource |
            Should -Be $(
                if ($CandidateReport) { 'Candidate' }
                else { 'Original' }
            )

        $Result.Report.EffectiveFindings[0].RuleId |
            Should -Be $(
                if ($CandidateReport) { 'Nitpick/UseIsNotOperator' }
                else { 'Local/Header' }
            )

        [IO.File]::ReadAllText($Path) | Should -BeExactly $Source
    }
}
