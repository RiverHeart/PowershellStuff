using namespace System.Collections
using namespace System.Management.Automation.Language
using module AstEditor

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\..\..\Nitpick.psd1" -Force -ErrorAction Stop
    . "$PSScriptRoot\..\..\..\..\Support\CorrectionFixtures.ps1"

    function New-TestSyntaxPolicy {
        param([string] $Minimum)

        return @{ Policy = @{ Compatibility = @{ PowerShell = @{ MinimumVersion = $Minimum } } } }
    }

    function New-TestSyntaxConfiguration {
        param([string] $Minimum)

        return @{ Compatibility = @{ PowerShell = @{ MinimumVersion = $Minimum } } }
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Ternary syntax compatibility' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'exposes metadata and is discoverable without evaluating host prerequisites' {
        $Details = Test-AvoidUnsupportedTernarySyntax -Details
        $Details.Name | Should -BeExactly 'AvoidUnsupportedTernarySyntax'
        $Details.Severity | Should -BeExactly 'Warning'
        $Details.MinimumAnalysisHostVersion | Should -Be ([version] '7.0')
        $Rule = Find-Nitpick -IncludeRule 'Nitpick/AvoidUnsupportedTernarySyntax'
        $Rule.Id | Should -BeExactly 'Nitpick/AvoidUnsupportedTernarySyntax'
    }

    It 'is inapplicable without policy and for minimum <Minimum>' -ForEach @(
        @{ Minimum = $null }
        @{ Minimum = '7.0' }
        @{ Minimum = '7.4' }
    ) {
        $Rule = Find-Nitpick -IncludeRule 'Nitpick/AvoidUnsupportedTernarySyntax'
        $Document = New-AstDocument -InputObject '$Value = 1'
        $Context = if ($Minimum) { New-TestSyntaxPolicy $Minimum } else { @{} }
        $Outcome = $Rule.InvokeWithResult($Document, $Context)
        $Outcome.Status | Should -BeExactly 'Inapplicable'
        $Outcome.Results | Should -HaveCount 0
    }

    It 'accepts a no-policy invocation and a 7.0 configuration on either host' {
        $Parameters = @{
            Script = '$Value = 1'
            IncludeRule = 'Nitpick/AvoidUnsupportedTernarySyntax'
            Output = 'Object'
            NoSummary = $true
            ErrorAction = 'Stop'
        }
        @(Start-Nitpicking @Parameters) | Should -HaveCount 0
        $Parameters.ConfigData = New-TestSyntaxConfiguration '7.0'
        @(Start-Nitpicking @Parameters) | Should -HaveCount 0
    }

    It 'does not report ternary syntax when the configured minimum is <Minimum>' `
        -Skip:($PSVersionTable.PSVersion.Major -lt 7) -ForEach @(
            @{ Minimum = '7.0' }
            @{ Minimum = '7.4' }
        ) {
        $Configuration = New-TestSyntaxConfiguration $Minimum
        @(Start-Nitpicking -Script '$Value = $true ? 1 : 2' `
            -ConfigData $Configuration `
            -IncludeRule Nitpick/AvoidUnsupportedTernarySyntax `
            -Output Object -NoSummary -ErrorAction Stop) | Should -HaveCount 0
    }

    It 'reports every ternary with native snapshot extents and no corrections for minimum <Minimum>' `
        -Skip:($PSVersionTable.PSVersion.Major -lt 7) -ForEach @(
            @{ Minimum = '5.1' }
            @{ Minimum = '6.0' }
            @{ Minimum = '6.2' }
        ) {
        $Source = '$First = $true ? 1 : 2; $Second = $false ? 3 : 4'
        $Document = New-AstDocument -InputObject $Source
        $Rule = Find-Nitpick -IncludeRule 'Nitpick/AvoidUnsupportedTernarySyntax'
        $Outcome = $Rule.InvokeWithResult($Document, (New-TestSyntaxPolicy $Minimum))

        $Outcome.Status | Should -BeExactly 'Executed'
        $Outcome.Results | Should -HaveCount 2
        foreach ($Finding in $Outcome.Results) {
            $Finding.RuleId | Should -BeExactly 'Nitpick/AvoidUnsupportedTernarySyntax'
            $Finding.Severity | Should -BeExactly 'Warning'
            $Finding.Corrections | Should -BeNullOrEmpty
            $Finding.ViolationExtent.Text | Should -Match '\?'
            $Source.Substring(
                $Finding.ViolationExtent.StartOffset,
                $Finding.ViolationExtent.EndOffset - $Finding.ViolationExtent.StartOffset
            ) | Should -BeExactly $Finding.ViolationExtent.Text
        }
    }

    It 'respects nested traversal and standalone diagnostic output' `
        -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        $Source = '$Outer = $true ? 1 : 2; & { $Inner = $false ? 3 : 4 }'
        $Document = New-AstDocument -InputObject $Source
        $Local = @(Test-AvoidUnsupportedTernarySyntax -ScriptBlockAst $Document.Ast)
        $Nested = @(Test-AvoidUnsupportedTernarySyntax -ScriptBlockAst $Document.Ast -Context @{
            RuleBehavior = @{ SearchNestedScriptBlocks = $true; OutputType = 'NitpickFinding' }
        })
        $Local | Should -HaveCount 1
        $Local[0].GetType().Name | Should -BeExactly 'DiagnosticRecord'
        $Nested | Should -HaveCount 2
    }

    It 'keeps snapshot coordinates when a nested fragment is submitted' `
        -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        $Fixture = New-TestSourceDocument -Kind Nested `
            -Source '$Value = $true ? 1 : 2' -Prefix "`$Other = 1`r`n"
        $Configuration = New-TestSyntaxConfiguration '5.1'
        $Findings = @(Start-Nitpicking -Script $Fixture.FragmentAst `
            -ConfigData $Configuration `
            -IncludeRule Nitpick/AvoidUnsupportedTernarySyntax `
            -Output Object -NoSummary -ErrorAction Stop)
        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.File | Should -BeExactly $Fixture.Path
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 2
        $Findings[0].ViolationExtent.Text | Should -BeExactly '$true ? 1 : 2'
    }

    It 'errors on an older host only when applicable and not whole-target suppressed' `
        -Skip:($PSVersionTable.PSVersion.Major -ge 7) {
        $Configuration = New-TestSyntaxConfiguration '5.1'
        $Parameters = @{
            ConfigData = $Configuration
            IncludeRule = 'Nitpick/AvoidUnsupportedTernarySyntax'
            Output = 'Object'
            NoSummary = $true
        }
        { Start-Nitpicking -Script '$Value = 1' @Parameters } |
            Should -Throw -ErrorId '*NitpickUnsupportedAnalysisHost*'
        { Start-Nitpicking -Script "# nitpick disable-target Nitpick/AvoidUnsupportedTernarySyntax`n`$Value = 1" @Parameters } |
            Should -Not -Throw
        { Start-Nitpicking -Script "`$Value = 1 # nitpick disable-line Nitpick/AvoidUnsupportedTernarySyntax" @Parameters } |
            Should -Throw -ErrorId '*NitpickUnsupportedAnalysisHost*'
    }

    It 'respects line suppression for compatibility findings on PowerShell 7' `
        -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        $Configuration = New-TestSyntaxConfiguration '5.1'
        $Source = '$Value = $true ? 1 : 2 # nitpick disable-line Nitpick/AvoidUnsupportedTernarySyntax'
        @(Start-Nitpicking -Script $Source -ConfigData $Configuration `
            -IncludeRule Nitpick/AvoidUnsupportedTernarySyntax `
            -Output Object -NoSummary -ErrorAction Stop) | Should -HaveCount 0
    }

    It 'lets a policy-aware producer refuse an incompatible fix and reports a noncompliant candidate' `
        -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        $State = @{ Noncompliant = $false }
        $Producer = {
            param([ScriptBlockAst] $ScriptBlockAst, [IDictionary] $Context)
            $Statement = $ScriptBlockAst.EndBlock.Statements[0]
            if ($Statement.Extent.Text -ne '$Value = 1') { return }

            $Corrections = @()
            $Minimum = $Context.Policy.Compatibility.PowerShell.MinimumVersion
            if ($State.Noncompliant -or $null -eq $Minimum -or $Minimum -ge [version] '7.0') {
                $Corrections = @(
                    New-NitpickCorrection -ViolationExtent $Statement.Extent `
                        -ReplacementText '$Value = $true ? 1 : 2' `
                        -FilePathOrContext '<ScriptBlock>' -Description 'Introduce ternary.'
                )
            }
            New-NitpickFinding -RuleId 'Local/Fixture' -Message 'Fixture finding.' `
                -ViolationExtent $Statement.Extent -Severity Information `
                -ScriptPath '<ScriptBlock>' -Explanation 'Exercises policy-aware fixes.' `
                -Corrections $Corrections
        }.GetNewClosure()
        $FixRule = New-Nitpick -Name Fixture -Source Tests -Callable $Producer
        $CompatibilityRule = Find-Nitpick -IncludeRule 'Nitpick/AvoidUnsupportedTernarySyntax'
        $PolicyContext = New-TestSyntaxPolicy '5.1'

        $Document = New-AstDocument -InputObject '$Value = 1'
        $Initial = @($FixRule.Invoke($Document, $PolicyContext))
        $Initial[0].Corrections | Should -BeNullOrEmpty
        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document `
            -Finding $Initial -Rule @($FixRule, $CompatibilityRule) -Context $PolicyContext
        $Proposal.Status | Should -BeExactly 'NoChanges'
        $Proposal.CandidateText | Should -BeExactly '$Value = 1'

        $Document = New-AstDocument -InputObject '$Value = 1'
        $SupportedContext = New-TestSyntaxPolicy '7.0'
        $SupportedFinding = @($FixRule.Invoke($Document, $SupportedContext))
        $SupportedFinding[0].Corrections | Should -HaveCount 1
        $SupportedProposal = Resolve-NitpickCorrectionProposal -Document $Document `
            -Finding $SupportedFinding -Rule @($FixRule, $CompatibilityRule) -Context $SupportedContext
        $SupportedProposal.Status | Should -BeExactly 'Ready'
        $SupportedProposal.CandidateFindings | Should -BeNullOrEmpty

        $Document = New-AstDocument -InputObject '$Value = 1'
        $State.Noncompliant = $true
        $Initial = @($FixRule.Invoke($Document, $PolicyContext))
        $Initial[0].Corrections | Should -HaveCount 1
        $Proposal = Resolve-NitpickCorrectionProposal -Document $Document `
            -Finding $Initial -Rule @($FixRule, $CompatibilityRule) -Context $PolicyContext
        $Proposal.Status | Should -BeExactly 'Ready'
        $Proposal.AcceptedCorrections | Should -HaveCount 1
        $Proposal.CandidateText | Should -BeExactly '$Value = $true ? 1 : 2'
        @($Proposal.CandidateFindings | Where-Object RuleId -eq 'Nitpick/AvoidUnsupportedTernarySyntax') |
            Should -HaveCount 1

        $Path = Join-Path $TestDrive 'noncompliant.ps1'
        [IO.File]::WriteAllText($Path, '$Value = 1')
        $Configuration = New-TestSyntaxConfiguration '5.1'
        Register-Nitpick -Callable $FixRule
        $Results = @(Start-Nitpicking -Path $Path -ConfigData $Configuration `
            -IncludeRule Local/Fixture,Nitpick/AvoidUnsupportedTernarySyntax `
            -FixMode Apply -Confirm:$false -Output Object -NoSummary -ErrorAction Stop)
        [IO.File]::ReadAllText($Path) | Should -BeExactly '$Value = $true ? 1 : 2'
        @($Results | Where-Object RuleId -eq 'Nitpick/AvoidUnsupportedTernarySyntax') |
            Should -HaveCount 1
    }
}
