using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    function Get-TestSuppression {
        param ([string] $Source)

        InModuleScope Nitpick -Parameters @{ Source = $Source } {
            param($Source)

            Get-NitpickSuppression -Document (New-AstDocument -InputObject $Source)
        }
    }

    function New-TestHeaderFinding {
        param(
            $Document,
            [string] $Replacement
        )

        $Comment = @($Document.Tokens | Where-Object Kind -eq Comment)[0]

        $Correction = New-NitpickCorrection `
            -ViolationExtent $Comment.Extent `
            -ReplacementText $Replacement `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Rewrite the header.'

        New-NitpickFinding `
            -RuleId 'Local/Header' `
            -Message 'Rewrite the header.' `
            -ViolationExtent $Comment.Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Exercises snapshot reanalysis.' `
            -Corrections $Correction
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Whole-target suppression grammar' {
    It 'accepts qualified selectors, comma/whitespace lists, reasons and preambles: <Label>' -ForEach @(
        @{ Label = 'literal'; Header = '# nitpick disable-target Nitpick/UseIsNotOperator'; Count = 1 }
        @{ Label = 'case'; Header = '# NiTpIcK disable-target nitpick/useisnotoperator'; Count = 1 }
        @{ Label = 'all'; Header = '#nitpick disable-target *'; Count = 1 }
        @{ Label = 'empty reason'; Header = '# nitpick disable-target * --'; Count = 1 }
        @{ Label = 'lists'; Header = '# nitpick disable-target Nitpick/*, */Other Local/Unknown -- arbitrary, reason'; Count = 3 }
        @{ Label = 'preamble'; Header = "#!/usr/bin/env pwsh`r`n<# help #>`r`n `t# nitpick disable-target Nitpick/*"; Count = 1 }
        @{ Label = 'multiple'; Header = "# nitpick disable-target Nitpick/*`n# nitpick disable-target Other/*"; Count = 2 }
    ) {
        $Result = Get-TestSuppression "$Header`n-not (`$Value -is [int])"
        $Result.Selectors | Should -HaveCount $Count
        $Result.Diagnostics | Should -HaveCount 0
    }

    It 'rejects the entire malformed directive: <Directive>' -ForEach @(
        @{ Directive = '# nitpick' }
        @{ Directive = '# nitpick disable-target' }
        @{ Directive = '# nitpick disable-target -- reason without selectors' }
        @{ Directive = '# nitpick disable-target UseIsNotOperator' }
        @{ Directive = '# nitpick disable-target Test-UseIsNotOperator' }
        @{ Directive = '# nitpick disable-target Nitpick/*,' }
        @{ Directive = '# nitpick disable-target ,Nitpick/*' }
        @{ Directive = '# nitpick disable-target Nitpick/*, ,Other/*' }
        @{ Directive = '# nitpick disable-target Nitpick/* Invalid' }
        @{ Directive = '# nitpick disable-target /Rule' }
        @{ Directive = '# nitpick disable-target Namespace/' }
        @{ Directive = '# nitpick disable-target A/B/C' }
        @{ Directive = '# nitpick disable-target Nitpick/[' }
        @{ Directive = '# nitpick unknown Nitpick/*' }
        @{ Directive = '# nitpick disable-file Nitpick/*' }
    ) {
        $Result = Get-TestSuppression "$Directive`n-not (`$Value -is [int])"
        $Result.Selectors | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 1
        $Result.Diagnostics[0].RuleId | Should -Be 'Nitpick/InvalidSuppressionDirective'
        $Result.Diagnostics[0].Severity | Should -Be Warning
        $Result.Diagnostics[0].ViolationExtent.Text | Should -BeExactly $Directive
    }

    It 'rejects misplaced directives: <Source>' -ForEach @(
        @{ Source = "`$Value = 1 # nitpick disable-target *" }
        @{ Source = "`$Value = 1`n# nitpick disable-target *" }
        @{ Source = "<# block #> # nitpick disable-target *" }
        @{ Source = "{`n# nitpick disable-target *`n}" }
    ) {
        $Result = Get-TestSuppression $Source
        $Result.Selectors | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 1
    }

    It 'ignores ordinary comments and literal string content: <Source>' -ForEach @(
        @{ Source = '# nitpicker disable-target *' }
        @{ Source = '<# nitpick disable-target * #>' }
        @{ Source = "'# nitpick disable-target *'" }
        @{ Source = '"# nitpick disable-target *"' }
        @{ Source = "@'`n# nitpick disable-target *`n'@" }
        @{ Source = "@`"`n# nitpick disable-target *`n`"@" }
    ) {
        $Result = Get-TestSuppression $Source
        $Result.Selectors | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 0
    }

    It 'recognizes actual nested comments without treating them as preamble' {
        $Source = '"$(' + "`n# nitpick disable-target *`n1)" + '"'
        $Result = Get-TestSuppression $Source
        $Result.Selectors | Should -HaveCount 0
        $Result.Diagnostics | Should -HaveCount 1
        $Result.Diagnostics[0].ViolationExtent.StartLineNumber | Should -Be 2
    }
}

Describe 'Whole-target suppression coordination' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'skips producers while retaining selected rule totals in <FixMode>' -ForEach @(
        @{ FixMode = 'Off' }
        @{ FixMode = 'Preview' }
        @{ FixMode = 'Apply' }
    ) {
        Register-Nitpick -Name NeverRun -Namespace Owner -Source Tests -Callable {
            param([ScriptBlockAst] $ScriptBlockAst)
            throw 'Suppressed producer must not execute.'
        }

        $Source = "# nitpick disable-target owner/*`n`$Value = 1"
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Owner/NeverRun `
            -FixMode $FixMode `
            -Output Object `
            -ErrorOn Information `
            -ErrorAction Stop
        )

        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.TargetCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        $Summary.InformationCount | Should -Be 0
        $Summary.WarningCount | Should -Be 0
        $Summary.ErrorCount | Should -Be 0

        if ($FixMode -ne 'Off') {
            $Proposal = ($Results | Where-Object {
                $_.GetType().Name -eq 'NitpickCorrectionResult'
            }).Proposal

            $Proposal.OriginalFindings | Should -HaveCount 0
            $Proposal.CandidateFindings | Should -HaveCount 0
            $Proposal.AcceptedCorrections | Should -HaveCount 0
            $Proposal.WasReanalyzed | Should -BeTrue
        }
    }

    It 'keeps file suppression independent and does not apply suppressed corrections' {
        $Suppressed = Join-Path $TestDrive 'Suppressed.ps1'
        $Active = Join-Path $TestDrive 'Active.ps1'
        $Source = "# nitpick disable-target Nitpick/UseIsNotOperator`r`n-not (`$Value -is [int])"
        [IO.File]::WriteAllText($Suppressed, $Source)
        [IO.File]::WriteAllText($Active, '-not ($Value -is [int])')

        $Results = @(@($Suppressed, $Active) | Start-Nitpicking `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Apply `
            -Output Object `
            -ErrorAction Stop
        )

        [IO.File]::ReadAllText($Suppressed) | Should -BeExactly $Source
        [IO.File]::ReadAllText($Active) | Should -BeExactly ' ($Value -isnot [int])'

        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.TargetCount | Should -Be 2
        $Summary.FindingCount | Should -Be 1
        $Summary.RuleCount | Should -Be 1
    }

    It 'matches the owning namespace rather than the implementing module or local name' {
        Register-Nitpick -Callable Test-UseIsNotOperator -Namespace Owner
        Register-Nitpick -Callable Test-UseIsNotOperator -Namespace Other

        $Results = @(Start-Nitpicking `
            -Script "# nitpick disable-target Owner/UseIsNotOperator`n-not (`$Value -is [int])" `
            -ExcludeRule 'Nitpick/*' `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        $Results | Should -HaveCount 1
        $Results[0].RuleId | Should -Be 'Other/UseIsNotOperator'
    }

    It 'does not bypass invocation selection validation' {
        { Start-Nitpicking `
            -Script '# nitpick disable-target *' `
            -IncludeRule Missing/Rule `
            -ErrorAction Stop
        } | Should -Throw '*No Nitpick rules match*'

        { Start-Nitpicking `
            -Script '# nitpick disable-target *' `
            -ExcludeRule '*' `
            -ErrorAction Stop
        } | Should -Throw '*No eligible Nitpick rules*'

        { Start-Nitpicking `
            -Script '# nitpick disable-target *' `
            -IncludeRule Nitpick/InvalidSuppressionDirective `
            -ErrorAction Stop
        } | Should -Throw '*No Nitpick rules match*'
    }

    It 'allows unmatched selectors without disabling other rules' {
        $Results = @(Start-Nitpicking `
            -Script "# nitpick disable-target Missing/Rule`n-not (`$Value -is [int])" `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        $Results | Should -HaveCount 1
        $Results[0].RuleId | Should -Be 'Nitpick/UseIsNotOperator'
    }

    It 'keeps malformed directive warnings visible under all-rules suppression in <FixMode>' -ForEach @(
        @{ FixMode = 'Off' }
        @{ FixMode = 'Preview' }
    ) {
        $Results = @(Start-Nitpicking `
            -Script "# nitpick disable-target *`n# nitpick disable-target Invalid`n-not (`$Value -is [int])" `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode $FixMode `
            -Output Object `
            -ErrorAction Stop
        )

        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/InvalidSuppressionDirective'

        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.WarningCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
    }

    It 'uses the warning threshold for invalid directives' {
        { Start-Nitpicking `
            -Script '# nitpick disable-target Invalid' `
            -IncludeRule Nitpick/UseIsNotOperator `
            -ErrorOn Warning `
            -Output Object `
            -ErrorAction Stop
        } | Should -Throw "*1 findings*'Warning'*"
    }

    It 'does not suppress parser findings' {
        $Path = Join-Path $TestDrive 'ParseError.ps1'
        [IO.File]::WriteAllText($Path, "# nitpick disable-target *`nif (")
        $Results = @(Start-Nitpicking `
            -Path $Path `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -ErrorAction SilentlyContinue
        )

        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Findings.Count | Should -BeGreaterThan 0
        @($Findings | Where-Object RuleId -ne 'Nitpick/PowerShellParseError') | Should -HaveCount 0
    }

    It 'does not show suppressed findings in text output' {
        Mock Write-Host -ModuleName Nitpick {}
        $Result = @(Start-Nitpicking `
            -Script "# nitpick disable-target *`n-not (`$Value -is [int])" `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Text `
            -NoSummary `
            -ErrorAction Stop
        )

        $Result | Should -HaveCount 0
    }

    It 'does not inherit directives outside a nested target and preserves coordinates' {
        $Tokens = $null
        $Errors = $null
        $Source = "# nitpick disable-target *`r`n& {`r`n-not (`$Value -is [int])`r`n}"
        $Root = [Parser]::ParseInput($Source, 'Nested.ps1', [ref] $Tokens, [ref] $Errors)

        $Nested = $Root.Find({
            param($Node)

            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Findings = @(Start-Nitpicking `
            -Script $Nested `
            -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 3
        $Findings[0].ViolationExtent.File | Should -BeExactly 'Nested.ps1'
    }
}

Describe 'Submitted ScriptBlock target boundaries' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'suppresses a directly submitted ScriptBlock in <FixMode>' -ForEach @(
        @{ FixMode = 'Off' }
        @{ FixMode = 'Preview' }
        @{ FixMode = 'Apply' }
    ) {
        Register-Nitpick -Name NeverRun -Source Tests -Callable {
            param([ScriptBlockAst] $ScriptBlockAst)
            throw 'The target directive must prevent original and candidate execution.'
        }
        $Results = @(Start-Nitpicking -Script {
            # nitpick disable-target Local/NeverRun
            $Value = 1
            & { $Other = 2 }
        } -IncludeRule Local/NeverRun -FixMode $FixMode -Output Object -ErrorAction Stop)

        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        if ($FixMode -ne 'Off') {
            $Proposal = ($Results | Where-Object {
                $_.GetType().Name -eq 'NitpickCorrectionResult'
            }).Proposal
            $Proposal.OriginalFindings | Should -HaveCount 0
            $Proposal.CandidateFindings | Should -HaveCount 0
            $Proposal.WasReanalyzed | Should -BeTrue
        }
    }

    It 'allows only the submitted nested AST to establish a body preamble with <NewLineName>' -ForEach @(
        @{ NewLineName = 'LF'; NewLine = "`n" }
        @{ NewLineName = 'CRLF'; NewLine = "`r`n" }
    ) {
        $Source = @(
            '$Before = 1; & {'
            '  <# ordinary help #>'
            '  # nitpick disable-target Nitpick/UseIsNotOperator'
            '  -not ($Value -is [int])'
            '}'
            '-not ($Outside -is [int])'
        ) -join $NewLine
        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseInput($Source, 'NestedTarget.ps1', [ref] $Tokens, [ref] $Errors)
        $Nested = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $NestedResults = @(Start-Nitpicking -Script $Nested -FixMode Preview `
            -IncludeRule Nitpick/UseIsNotOperator -Output Object -NoSummary -ErrorAction Stop)
        $NestedProposal = ($NestedResults | Where-Object {
            $_.GetType().Name -eq 'NitpickCorrectionResult'
        }).Proposal
        $NestedProposal.OriginalFindings | Should -HaveCount 0
        $NestedProposal.CandidateFindings | Should -HaveCount 0
        $NestedProposal.AcceptedCorrections | Should -HaveCount 0
        $NestedProposal.SourcePath | Should -BeExactly 'NestedTarget.ps1'

        $RootFindings = @(Start-Nitpicking -Script $Root `
            -IncludeRule Nitpick/UseIsNotOperator -Output Object -NoSummary -ErrorAction Stop)
        @($RootFindings | Where-Object RuleId -eq 'Nitpick/UseIsNotOperator') | Should -HaveCount 2
        $Diagnostic = @($RootFindings | Where-Object RuleId -eq 'Nitpick/InvalidSuppressionDirective')
        $Diagnostic | Should -HaveCount 1
        $Diagnostic[0].ViolationExtent.StartLineNumber | Should -Be 3
        $Diagnostic[0].ViolationExtent.File | Should -BeExactly 'NestedTarget.ps1'
    }

    It 'rejects misplaced directives inside a submitted block: <Label>' -ForEach @(
        @{ Label = 'same line as brace'; Body = '# nitpick disable-target *' }
        @{ Label = 'after code'; Body = "`n`$Value = 1`n# nitpick disable-target *" }
        @{ Label = 'after param'; Body = "`nparam()`n# nitpick disable-target *" }
        @{ Label = 'inside a nested block'; Body = "`n& {`n# nitpick disable-target *`n}" }
    ) {
        $Block = [scriptblock]::Create("{$Body`n-not (`$Value -is [int])`n}")
        $Nested = $Block.Ast.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock
        $Results = @(Start-Nitpicking -Script $Nested -IncludeRule Nitpick/UseIsNotOperator `
            -Output Object -NoSummary -ErrorAction Stop)
        @($Results | Where-Object RuleId -eq 'Nitpick/UseIsNotOperator') | Should -HaveCount 1
        @($Results | Where-Object RuleId -eq 'Nitpick/InvalidSuppressionDirective') | Should -HaveCount 1
    }

    It 'recomputes body directives after a fragment correction <Label> them' -ForEach @(
        @{ Label = 'removes'; Original = '# nitpick disable-target Nitpick/*'; Replacement = '# ordinary'; OriginalCount = 1; CandidateCount = 1 }
        @{ Label = 'adds'; Original = '# ordinary'; Replacement = '# nitpick disable-target Nitpick/*'; OriginalCount = 2; CandidateCount = 0 }
        @{ Label = 'moves'; Original = '# nitpick disable-target Nitpick/*'; Replacement = "`$Header = 1`n# nitpick disable-target Nitpick/*"; OriginalCount = 1; CandidateCount = 2 }
    ) {
        $Source = "`$Before = 1; & {`r`n$Original`r`n-not (`$Value -is [int])`r`n}"
        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseInput($Source, 'Fragment.ps1', [ref] $Tokens, [ref] $Errors)
        $Nested = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock
        $Document = New-AstDocument -InputObject $Nested
        $HeaderFinding = New-TestHeaderFinding -Document $Document -Replacement $Replacement
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Native = @($Rule.Invoke($Document))
        $Native[0].Corrections[0].Applicability = 'Review'

        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document `
            -Finding @($HeaderFinding; $Native) -Rule $Rule
        $Proposal.OriginalFindings | Should -HaveCount $OriginalCount
        $Proposal.CandidateFindings | Should -HaveCount $CandidateCount
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.WasReanalyzed | Should -BeTrue
        foreach ($Finding in $Proposal.CandidateFindings) {
            $Finding.ViolationExtent.File | Should -BeExactly 'Fragment.ps1'
            $Finding.ViolationExtent.StartLineNumber | Should -BeGreaterThan 1
        }
    }
}

Describe 'Whole-target suppression in correction proposals' {
    BeforeEach {
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
    }

    It 'filters standalone original findings before invoking a correction selector with <InputKind>' -ForEach @(
        @{ InputKind = 'Document' }
        @{ InputKind = 'Script' }
    ) {
        $Source = "# nitpick disable-target Nitpick/*`n-not (`$Value -is [int])"
        $Document = New-AstDocument -InputObject $Source
        $Findings = @($Rule.Invoke($Document))
        $OriginalCorrections = $Findings[0].Corrections
        $OriginalCorrections[0].Applicability = 'Review'

        $InputParameters = if ($InputKind -eq 'Document') {
            @{ Document = $Document }
        } else {
            @{ Script = $Source }
        }

        $Proposal = Resolve-NitpickCorrectionProposal `
            @InputParameters `
            -Finding $Findings `
            -Rule $Rule `
            -CorrectionSelector { throw 'Suppressed findings must not be offered.' }

        $Proposal.OriginalFindings | Should -HaveCount 0
        $Proposal.CandidateFindings | Should -HaveCount 0
        $Proposal.AcceptedCorrections | Should -HaveCount 0
        $Proposal.SkippedCorrections | Should -HaveCount 1
        $Proposal.SkippedCorrections[0].Reason | Should -BeLike '*suppressed*disable-target*'
        $Proposal.CandidateText | Should -BeExactly $Source
        [object]::ReferenceEquals($OriginalCorrections, $Findings[0].Corrections) | Should -BeTrue
    }

    It 'recomputes candidate suppression when a correction <Label> the directive' -ForEach @(
        @{ Label = 'removes'; Original = '# nitpick disable-target Nitpick/*'; Replacement = '# ordinary'; OriginalCount = 1; CandidateCount = 1 }
        @{ Label = 'adds'; Original = '# ordinary'; Replacement = '# nitpick disable-target Nitpick/*'; OriginalCount = 2; CandidateCount = 0 }
        @{ Label = 'malforms'; Original = '# nitpick disable-target Nitpick/*'; Replacement = '# nitpick disable-target Invalid'; OriginalCount = 1; CandidateCount = 2 }
        @{ Label = 'moves below code'; Original = '# nitpick disable-target Nitpick/*'; Replacement = "`$Header = 1`n# nitpick disable-target Nitpick/*"; OriginalCount = 1; CandidateCount = 2 }
    ) {
        $Document = New-AstDocument -InputObject "$Original`n-not (`$Value -is [int])"
        $HeaderFinding = New-TestHeaderFinding -Document $Document -Replacement $Replacement

        # Review-only keeps the native finding reportable without selecting its edit.
        $Native = @($Rule.Invoke($Document))
        $Native[0].Corrections[0].Applicability = 'Review'
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding @($HeaderFinding; $Native) `
            -Rule $Rule

        $Proposal.OriginalFindings | Should -HaveCount $OriginalCount
        $Proposal.CandidateFindings | Should -HaveCount $CandidateCount
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.WasReanalyzed | Should -BeTrue

        if ($Label -eq 'malforms') {
            @($Proposal.CandidateFindings | Where-Object RuleId -eq 'Nitpick/InvalidSuppressionDirective') |
                Should -HaveCount 1
        }
    }

    It 'preserves original versus candidate suppression when a file write is declined' {
        $Path = Join-Path $TestDrive 'Declined.ps1'
        $Source = "# nitpick disable-target Nitpick/*`n-not (`$Value -is [int])"
        [IO.File]::WriteAllText($Path, $Source)
        $Document = New-AstDocument -Path $Path
        $HeaderFinding = New-TestHeaderFinding -Document $Document -Replacement '# ordinary'

        Mock Should-Process -ModuleName Nitpick { $false }

        $Result = InModuleScope Nitpick -Parameters @{
            Document = $Document; HeaderFinding = $HeaderFinding; Rule = $Rule
        } {
            param($Document, $HeaderFinding, $Rule)

            Resolve-NitpickTargetCorrection `
                -Document $Document `
                -Finding @($HeaderFinding) `
                -Rule @($Rule) `
                -FixMode Apply
        }

        $Result.Application.Status | Should -Be Declined
        $Result.Report.AnalysisSource | Should -Be Original
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0].RuleId | Should -Be Local/Header
        $Result.Proposal.CandidateFindings | Should -HaveCount 1
        $Result.Proposal.CandidateFindings[0].RuleId | Should -Be Nitpick/UseIsNotOperator
        [IO.File]::ReadAllText($Path) | Should -BeExactly $Source
    }

    It 'keeps suppression active during WhatIf without writing the file' {
        $Path = Join-Path $TestDrive 'WhatIf.ps1'
        $Source = "# nitpick disable-target Nitpick/UseIsNotOperator`n-not (`$Value -is [int])"
        [IO.File]::WriteAllText($Path, $Source)

        $Results = @(Start-Nitpicking `
            -Path $Path `
            -IncludeRule Nitpick/UseIsNotOperator `
            -FixMode Apply `
            -WhatIf `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop
        )

        $Result = $Results | Where-Object { $_.GetType().Name -eq 'NitpickCorrectionResult' }
        $Result.Proposal.OriginalFindings | Should -HaveCount 0
        $Result.Proposal.CandidateFindings | Should -HaveCount 0
        $Result.Proposal.AcceptedCorrections | Should -HaveCount 0
        [IO.File]::ReadAllText($Path) | Should -BeExactly $Source
    }

    It 'retains originally suppressed descriptors for candidate re-enablement through Start-Nitpicking' {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }

        Register-Nitpick -Name Header -Source Tests -Callable {
            param([ScriptBlockAst] $ScriptBlockAst)

            $Document = New-AstDocument -InputObject $ScriptBlockAst
            $Comment = @($Document.Tokens | Where-Object Kind -eq Comment)[0]

            if ($Comment.Text -like '# nitpick disable-target*') {
                $Correction = New-NitpickCorrection `
                    -ViolationExtent $Comment.Extent `
                    -ReplacementText '# ordinary' `
                    -FilePathOrContext '<ScriptBlock>' `
                    -Description 'Remove the directive.'

                New-NitpickFinding `
                    -RuleId Local/Header `
                    -Message 'Remove the directive.' `
                    -ViolationExtent $Comment.Extent `
                    -Severity Information `
                    -ScriptPath '<ScriptBlock>' `
                    -Explanation 'Test re-enablement.' `
                    -Corrections $Correction
            }
        }
        try {
            $Results = @(Start-Nitpicking `
                -Script "# nitpick disable-target Nitpick/*`n-not (`$Value -is [int])" `
                -IncludeRule Local/Header,Nitpick/UseIsNotOperator `
                -FixMode Preview `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
            )

            $Proposal = ($Results | Where-Object {
                $_.GetType().Name -eq 'NitpickCorrectionResult'
            }).Proposal

            $Proposal.OriginalFindings | Should -HaveCount 1
            $Proposal.OriginalFindings[0].RuleId | Should -Be Local/Header
            $Proposal.CandidateFindings | Should -HaveCount 1
            $Proposal.CandidateFindings[0].RuleId | Should -Be Nitpick/UseIsNotOperator
        } finally {
            InModuleScope Nitpick {
                (Get-NitpickRegistry).Nitpicks.Clear()
            }
        }
    }
}
