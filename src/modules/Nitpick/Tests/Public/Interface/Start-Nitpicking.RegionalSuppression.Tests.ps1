using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    function Get-TestRegionalSuppression {
        param ([string] $Source)
        InModuleScope Nitpick -Parameters @{ Source = $Source } {
            param($Source)
            Get-NitpickSuppression -Document (New-AstDocument -InputObject $Source)
        }
    }

    function New-TestRegionHeaderFinding {
        param ($Document, [string] $Replacement, [int] $CommentIndex = 0)

        $Comment = @($Document.Tokens | Where-Object Kind -eq Comment)[$CommentIndex]
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Comment.Extent `
            -ReplacementText $Replacement `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Rewrite the regional directive.'

        New-NitpickFinding `
            -RuleId Local/Header `
            -Message 'Rewrite the regional directive.' `
            -ViolationExtent $Comment.Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises regional candidate reanalysis.' `
            -Corrections $Correction
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Regional suppression grammar' {
    It 'parses standalone ordered directives with qualified selectors and reasons' {
        $Result = Get-TestRegionalSuppression @'
$Value = 1
# NiTpIcK DISABLE Nitpick/*, */Other Local/Unknown -- arbitrary, reason
# nitpick ENABLE nitpick/UseIsNotOperator
# nitpick disable * --
'@
        $Result.Diagnostics | Should -HaveCount 0
        $Result.Selectors | Should -HaveCount 0
        $Result.LineSelectors.Count | Should -Be 0
        $Result.Regions | Should -HaveCount 3
        $Result.Regions.StartLineNumber | Should -Be @(3, 4, 5)
        $Result.Regions.Disabled | Should -Be @($true, $false, $true)
        $Result.Regions[0].Selectors | Should -Be @('Nitpick/*', '*/Other', 'Local/Unknown')
    }

    It 'rejects malformed or misplaced regional directives as a whole: <Source>' -ForEach @(
        @{ Source = '# nitpick disable' }
        @{ Source = '# nitpick enable' }
        @{ Source = '# nitpick disable -- missing selectors' }
        @{ Source = '# nitpick enable Nitpick/*,' }
        @{ Source = '# nitpick disable Nitpick/*, ,Other/*' }
        @{ Source = '# nitpick enable Nitpick/* BareName' }
        @{ Source = '# nitpick disable Nitpick/[' }
        @{ Source = '$Value = 1 # nitpick disable *' }
        @{ Source = '$Value = 1 # nitpick enable *' }
        @{ Source = '<# ordinary #> # nitpick disable *' }
        @{ Source = '{ # nitpick enable *' }
    ) {
        $Result = Get-TestRegionalSuppression $Source
        $Result.Regions | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 1
        $Result.Diagnostics[0].RuleId | Should -Be Nitpick/InvalidSuppressionDirective
        $Result.Diagnostics[0].ViolationExtent.Text | Should -BeLike '*# nitpick*'
    }

    It 'ignores directive-shaped literal text: <Source>' -ForEach @(
        @{ Source = "'# nitpick disable *'" }
        @{ Source = '"# nitpick enable *"' }
        @{ Source = "@'`n# nitpick disable *`n'@" }
        @{ Source = "@`"`n# nitpick enable *`n`"@" }
        @{ Source = "<#`n# nitpick disable *`n# nitpick enable *`n#>" }
    ) {
        $Result = Get-TestRegionalSuppression $Source
        $Result.Regions | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 0
    }

    It 'restores source order across nested expandable-string tokens' {
        #=== Arrange ===#
        $Source = @'
# nitpick disable *
"$(
# nitpick enable Nitpick/UseIsNotOperator
-not ($First -is [int])
)"
# nitpick disable Nitpick/*
-not ($Second -is [int])
'@
        #=== Act ===#
        $Result = Get-TestRegionalSuppression $Source
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Result.Regions.StartLineNumber | Should -Be @(2, 4, 7)
        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 4
    }
}

Describe 'Regional state and reporting' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'uses the last matching directive rather than a stack: <Label>' -ForEach @(
        @{ Label = 'enabled by default'; Header = '# ordinary'; Count = 1 }
        @{ Label = 'unmatched enable'; Header = '# nitpick enable Nitpick/*'; Count = 1 }
        @{ Label = 'unclosed disable'; Header = '# nitpick disable Nitpick/*'; Count = 0 }
        @{ Label = 'repeated disables'; Header = "# nitpick disable *`n# nitpick disable *`n# nitpick enable Nitpick/*"; Count = 1 }
        @{ Label = 'unrelated enable'; Header = "# nitpick disable Nitpick/*`n# nitpick enable Other/*"; Count = 0 }
        @{ Label = 'later wildcard disable'; Header = "# nitpick enable Nitpick/*`n# nitpick disable *"; Count = 0 }
        @{ Label = 'unknown disable'; Header = '# nitpick disable Missing/Rule'; Count = 1 }
        @{ Label = 'enable multiple selectors'; Header = "# nitpick disable *`n# nitpick enable Other/*, nitpick/useisnotoperator"; Count = 1 }
    ) {
        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script "$Header`n-not (`$Value -is [int])" `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount $Count
    }

    It 'starts state changes on the next line, including findings on directive comments' {
        #=== Arrange ===#
        $Source = "# nitpick disable Nitpick/*   `n# nitpick enable Nitpick/*   `n`$Value = 1   "

        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/AvoidTrailingWhitespace `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 2
        $Findings.ViolationExtent.StartLineNumber | Should -Be @(1, 3)
    }

    It 'anchors multiline findings by start line, not suppressed overlap' {
        #=== Arrange ===#
        $Source = @'
-not (
# nitpick disable Nitpick/*
$First -is [int])
-not ($Second -is [int])
# nitpick enable Nitpick/*
-not ($Third -is [int])
'@
        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 2
        $Findings.ViolationExtent.StartLineNumber | Should -Be @(1, 6)
    }

    It 'does not reset textual state at function or scriptblock boundaries' {
        #=== Arrange ===#
        $Source = @'
function Test-Nested {
    # nitpick disable Nitpick/*
    -not ($First -is [int])
}
-not ($Second -is [int])
& {
    # nitpick enable Nitpick/*
    -not ($Third -is [int])
}
-not ($Fourth -is [int])
'@
        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 2
        $Findings.ViolationExtent.StartLineNumber | Should -Be @(8, 10)
    }

    It 'reenables only the matching owning namespace under a wildcard disable' {
        #=== Arrange ===#
        Register-Nitpick -Callable Test-UseIsNotOperator -Namespace Owner
        Register-Nitpick -Callable Test-UseIsNotOperator -Namespace Other
        $Source = "# nitpick disable *`n# nitpick enable owner/UseIsNotOperator`n-not (`$Value -is [int])"

        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Source `
            -ExcludeDefaults `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be Owner/UseIsNotOperator
    }

    It 'cannot override whole-target, line, next-line, or invocation exclusions: <Label>' -ForEach @(
        @{ Label = 'whole-target'; Source = "# nitpick disable-target Nitpick/*`n# nitpick enable *`n-not (`$Value -is [int])" }
        @{ Label = 'same-line'; Source = "# nitpick disable *`n# nitpick enable *`n-not (`$Value -is [int]) # nitpick disable-line *" }
        @{ Label = 'next-line'; Source = "# nitpick disable *`n# nitpick enable *`n# nitpick disable-next-line *`n-not (`$Value -is [int])" }
    ) {
        @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorOn Information `
            -ErrorAction Stop
        ) | Should -HaveCount 0

        { Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -ExcludeRule Nitpick/* `
            -ErrorAction Stop
        } | Should -Throw '*No eligible Nitpick rules*'
    }

    It 'ignores a malformed enable without partially reenabling its valid selectors' {
        #=== Arrange ===#
        $Source = "# nitpick disable *`n# nitpick enable Nitpick/* Invalid`n-not (`$Value -is [int])"

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Preview `
            -Output Object `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be Nitpick/InvalidSuppressionDirective

        $Result = $Results | Where-Object { $_.GetType().Name -eq 'NitpickCorrectionResult' }
        $Result.Proposal.OriginalFindings | Should -HaveCount 1
        $Result.Proposal.CandidateFindings | Should -HaveCount 1

        { Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -ErrorOn Warning `
            -ErrorAction Stop
        } | Should -Throw "*'Warning'*"
    }

    It 'keeps parser findings visible within a disabled region' {
        #=== Arrange ===#
        $Path = Join-Path $TestDrive 'SyntaxError.ps1'
        [IO.File]::WriteAllText($Path, "# nitpick disable *`nif (")

        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Path $Path `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction SilentlyContinue
        )

        #=== Assert ===#
        @($Findings | Where-Object RuleId -eq 'Nitpick/PowerShellParseError').Count | Should -BeGreaterThan 0
    }

    It 'does not infer native suppression identity from external output' {
        #=== Arrange ===#
        Register-Nitpick -Name External -Source Tests -Callable {
            param([ScriptBlockAst] $ScriptBlockAst)

            [pscustomobject]@{
                RuleId = 'Local/External'
                Message = 'Non-native output.'
                Severity = 'Information'
                ViolationExtent = $ScriptBlockAst.EndBlock.Statements[0].Extent
            }
        }

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script "# nitpick disable *`n`$Value = 1" `
            -IncludeRule Local/External `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Results | Should -HaveCount 1
        $Results[0].Message | Should -Be 'Non-native output.'
    }

    It 'accepts EOF directives without requiring balanced regions' {
        $Source = "`$Value = 1`n# nitpick disable Nitpick/*"
        $Result = Get-TestRegionalSuppression $Source
        $Result.Diagnostics | Should -HaveCount 0
        $Result.Regions | Should -HaveCount 1

        @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        ) | Should -HaveCount 0
    }

    It 'runs producers but removes suppressed findings before correction counts and thresholds in <FixMode>' -ForEach @(
        @{ FixMode = 'Off' }
        @{ FixMode = 'Preview' }
        @{ FixMode = 'Apply' }
    ) {
        #=== Arrange ===#
        $Calls = [System.Collections.Generic.List[object]]::new()
        $Callable = {
            param([ScriptBlockAst] $ScriptBlockAst)

            $Calls.Add($ScriptBlockAst)
            New-NitpickFinding `
                -RuleId Local/Observed `
                -Message 'Observed invocation.' `
                -ViolationExtent $ScriptBlockAst.EndBlock.Statements[0].Extent `
                -Severity Warning `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Checks producer dispatch.'
        }.GetNewClosure()

        Register-Nitpick -Name Observed -Source Tests -Callable $Callable

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Script "# nitpick disable Local/*`n`$Value = 1" `
            -IncludeRule Local/Observed `
            -FixMode $FixMode `
            -Output Object `
            -ErrorOn Warning `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Calls.Count | Should -Be $(if ($FixMode -eq 'Off') { 1 } else { 2 })
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        $Summary.WarningCount | Should -Be 0
        $Summary.CorrectedFindingCount | Should -Be 0
        $Summary.SkippedFindingCount | Should -Be 0
    }

    It 'keeps file state independent and persists only unsuppressed corrections' {
        #=== Arrange ===#
        $First = Join-Path $TestDrive 'First.ps1'
        $Second = Join-Path $TestDrive 'Second.ps1'
        $Source = "# nitpick disable Nitpick/*`n-not (`$Value -is [int])"
        [IO.File]::WriteAllText($First, $Source)
        [IO.File]::WriteAllText($Second, '-not ($Value -is [int])')

        #=== Act ===#
        $Results = @(@($First, $Second) | Start-Nitpicking `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Apply `
            -Output Object `
            -ErrorAction Stop
        )

        #=== Assert ===#
        [IO.File]::ReadAllText($First) | Should -BeExactly $Source
        [IO.File]::ReadAllText($Second) | Should -BeExactly ' ($Value -isnot [int])'
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.TargetCount | Should -Be 2
        $Summary.FindingCount | Should -Be 1
        $Summary.CorrectedFindingCount | Should -Be 1
    }

    It 'omits regional findings from text output' {
        Mock Write-Host -ModuleName Nitpick {}
        @(Start-Nitpicking `
            -Script "# nitpick disable *`n-not (`$Value -is [int])" `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Text `
            -NoSummary `
            -ErrorAction Stop
        ) | Should -HaveCount 0
    }

    It 'starts fragment state enabled without inheriting outer regions using <NewLineName>' -ForEach @(
        @{ NewLineName = 'LF'; NewLine = "`n" }
        @{ NewLineName = 'CRLF'; NewLine = "`r`n" }
    ) {
        #=== Arrange ===#
        $Source = @(
            '# nitpick disable *'
            '& { -not ($First -is [int])'
            '  # nitpick disable Nitpick/*'
            '  -not ($Second -is [int])'
            '  # nitpick enable Nitpick/*'
            '  -not ($Third -is [int])'
            '}'
        ) -join $NewLine

        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseInput($Source, 'RegionalFragment.ps1', [ref] $Tokens, [ref] $Errors)

        $Nested = $Root.Find({
            param($Node)

            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        #=== Act ===#
        $Findings = @(Start-Nitpicking `
            -Script $Nested `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Findings | Should -HaveCount 2
        $Findings.ViolationExtent.StartLineNumber | Should -Be @(2, 6)
        foreach ($Finding in $Findings) {
            $Finding.ViolationExtent.File | Should -BeExactly 'RegionalFragment.ps1'
        }
    }
}

Describe 'Regional suppression in correction proposals' {
    BeforeEach {
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
    }

    It 'excludes complete corrections before guided selection with <InputKind>' -ForEach @(
        @{ InputKind = 'Document' }
        @{ InputKind = 'Script' }
    ) {
        #=== Arrange ===#
        $Source = "# nitpick disable Nitpick/*`n-not (`$First -is [int])`n# nitpick enable Nitpick/*`n-not (`$Second -is [int])"
        $Document = New-AstDocument -InputObject $Source

        #=== Act ===#
        $Native = @($Rule.Invoke($Document))
        $Corrections = $Native[0].Corrections
        $Edits = $Corrections[0].TextEdits

        $InputParameters = if ($InputKind -eq 'Document') {
            @{ Document = $Document }
        } else {
            @{ Script = $Source }
        }

        $Proposal = Resolve-NitpickCorrectionProposal `
            @InputParameters `
            -Finding $Native `
            -Rule $Rule `
            -CorrectionSelector {
                throw 'Suppressed findings must never reach the selector.'
            }

        #=== Assert ===#
        $Edits | Should -HaveCount 2
        $Corrections[0].Applicability = 'Review'

        $Proposal.OriginalFindings | Should -HaveCount 1
        $Proposal.OriginalFindings[0].ViolationExtent.StartLineNumber | Should -Be 4
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.CandidateFindings | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount 1
        $Proposal.SkippedCorrections[0].Reason | Should -BeLike '*regional disable*'
        $Proposal.UndecidedFindings | Should -HaveCount 0
        $Proposal.SkippedFindings | Should -HaveCount 0
        $Proposal.CandidateText | Should -Match '\-not \(\$First -is \[int\]\)'
        $Proposal.CandidateText | Should -Match '\$Second -isnot'

        [object]::ReferenceEquals($Corrections, $Native[0].Corrections) | Should -BeTrue
        [object]::ReferenceEquals($Edits, $Native[0].Corrections[0].TextEdits) | Should -BeTrue
    }

    It 'recomputes candidate state when another rule <Label> a directive' -ForEach @(
        @{ Label = 'removes disable'; Original = '# nitpick disable Nitpick/*'; Replacement = '# ordinary'; OriginalCount = 1; CandidateCount = 1 }
        @{ Label = 'adds disable'; Original = '# ordinary'; Replacement = '# nitpick disable Nitpick/*'; OriginalCount = 2; CandidateCount = 0 }
        @{ Label = 'replaces disable with enable'; Original = '# nitpick disable Nitpick/*'; Replacement = '# nitpick enable Nitpick/*'; OriginalCount = 1; CandidateCount = 1 }
        @{ Label = 'moves disable after the finding'; Original = '# nitpick disable Nitpick/*'; Replacement = "-not (`$Inserted -is [int])`n# nitpick disable Nitpick/*"; OriginalCount = 1; CandidateCount = 1 }
        @{ Label = 'invalidates disable'; Original = '# nitpick disable Nitpick/*'; Replacement = '# nitpick disable Invalid'; OriginalCount = 1; CandidateCount = 2 }
        @{ Label = 'reorders enable before disable'; Original = "# nitpick disable Nitpick/*"; Replacement = "# nitpick enable Nitpick/*`n# nitpick disable Nitpick/*"; OriginalCount = 1; CandidateCount = 0 }
    ) {
        #=== Arrange ===#
        $Document = New-AstDocument -InputObject "$Original`n-not (`$Value -is [int])"
        $Header = New-TestRegionHeaderFinding `
            -Document $Document `
            -Replacement $Replacement

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
        $Proposal.WasReanalyzed | Should -BeTrue
    }

    It 'reenables findings when another rule adds an enable after an existing disable' {
        #=== Arrange ===#
        $Document = New-AstDocument -InputObject "# ordinary`n-not (`$Value -is [int])"
        $Header = New-TestRegionHeaderFinding `
            -Document $Document `
            -Replacement "# nitpick disable Nitpick/*`n# nitpick enable Nitpick/*"

        #=== Act ===#
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Header `
            -Rule $Rule

        #=== Assert ===#
        $Proposal.CandidateFindings | Should -HaveCount 1
        $Proposal.CandidateFindings[0].ViolationExtent.StartLineNumber | Should -Be 3
    }

    It 'recomputes state when another rule <Label> an enable' -ForEach @(
        @{ Label = 'removes'; Replacement = '# ordinary'; CandidateCount = 0 }
        @{ Label = 'invalidates'; Replacement = '# nitpick enable Invalid'; CandidateCount = 1 }
        @{ Label = 'moves after a finding'; Replacement = "-not (`$Inserted -is [int])`n# nitpick enable Nitpick/*"; CandidateCount = 1 }
    ) {
        #=== Arrange ===#
        $Source = "# nitpick disable Nitpick/*`n# nitpick enable Nitpick/*`n-not (`$Value -is [int])"
        $Document = New-AstDocument -InputObject $Source
        $Header = New-TestRegionHeaderFinding `
            -Document $Document `
            -CommentIndex 1 `
            -Replacement $Replacement

        #=== Act ===#
        $Native = @($Rule.Invoke($Document))
        $Native[0].Corrections[0].Applicability = 'Review'
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($Header; $Native) `
            -Rule $Rule

        #=== Assert ===#
        $Proposal.OriginalFindings | Should -HaveCount 2
        $Proposal.CandidateFindings | Should -HaveCount $CandidateCount
        $Proposal.AcceptedCorrections | Should -HaveCount 1
    }

    It 'keeps original and candidate regional facts when a file write is <Outcome>' -ForEach @(
        @{ Outcome = 'declined'; Status = 'Declined'; CandidateReport = $false }
        @{ Outcome = 'WhatIf'; Status = 'WhatIf'; CandidateReport = $true }
        @{ Outcome = 'failed'; Status = 'FailedWrite'; CandidateReport = $false }
    ) {
        #=== Arrange ===#
        $Path = Join-Path $TestDrive 'Application.ps1'
        $Source = "# nitpick disable Nitpick/*`n-not (`$Value -is [int])"
        [IO.File]::WriteAllText($Path, $Source)
        $Document = New-AstDocument -Path $Path
        $Header = New-TestRegionHeaderFinding -Document $Document -Replacement '# ordinary'

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
                        'TestWriteFailure', [System.Management.Automation.ErrorCategory]::WriteError, $null)
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
        $Result.Report.AnalysisSource | Should -Be $(if ($CandidateReport) { 'Candidate' } else { 'Original' })
        $Result.Report.EffectiveFindings[0].RuleId |
            Should -Be $(
                if ($CandidateReport) { 'Nitpick/UseIsNotOperator' }
                else { 'Local/Header' }
        )

        [IO.File]::ReadAllText($Path) | Should -BeExactly $Source
    }

    It 'rebuilds regional positions after fragment edits shift snapshot lines' {
        #=== Arrange ===#
        $Source = @'
$Prefix = 1; & {
# ordinary
# nitpick disable Nitpick/*
-not ($First -is [int])
# nitpick enable Nitpick/*
-not ($Second -is [int])
}
'@
        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseInput($Source, 'ShiftedRegion.ps1', [ref] $Tokens, [ref] $Errors)

        $Nested = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Document = New-AstDocument -InputObject $Nested
        $Header = New-TestRegionHeaderFinding -Document $Document -Replacement "# ordinary`n# extra line"

        #=== Act ===#
        $Native = @($Rule.Invoke($Document))
        foreach ($Finding in $Native) { $Finding.Corrections[0].Applicability = 'Review' }
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($Header; $Native) `
            -Rule $Rule

        #=== Assert ===#
        $Proposal.OriginalFindings | Should -HaveCount 2
        $Proposal.CandidateFindings | Should -HaveCount 1
        $Proposal.CandidateFindings[0].ViolationExtent.StartLineNumber | Should -Be 7
        $Proposal.CandidateFindings[0].ViolationExtent.File | Should -BeExactly 'ShiftedRegion.ps1'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
    }
}
