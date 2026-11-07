using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force -ErrorAction Stop

    function Invoke-CollectionComparisonPredicateRule {
        param([string] $Source)

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty

        Test-CollectionComparisonUsedAsAPredicate -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{ OutputType = 'NitpickFinding' }
        }
    }
}

Describe 'Test-CollectionComparisonUsedAsAPredicate' {
    It 'reports collection equality predicates and recommends a matching membership operator' {
        $Source = @'
param([int[]]$Values)
if ($Values -eq 0) {}
if ($Values -ne 1) {}
if ($Values -ceq 2) {}
'@

        $Findings = @(Invoke-CollectionComparisonPredicateRule -Source $Source)

        $Findings | Should -HaveCount 3
        $Findings[0].Message | Should -BeLike '*-contains*'
        $Findings[1].Message | Should -BeLike '*-notcontains*'
        $Findings[2].Message | Should -BeLike '*-ccontains*'
        $Findings[0].Severity | Should -Be 'Warning'
    }

    It 'does not report scalar comparisons, non-condition comparisons, or membership tests' {
        $Source = @'
param([int]$Value, [int[]]$Values)
if ($Value -eq 0) {}
$Match = $Values -eq 0
if ($Values -contains 0) {}
'@

        @(Invoke-CollectionComparisonPredicateRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'reports array expressions used as predicates' {
        $Findings = @(Invoke-CollectionComparisonPredicateRule -Source 'if (@(0, 1) -eq 0) {}')

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.Text | Should -Be '@(0, 1) -eq 0'
    }

    It 'exposes rule metadata' {
        $Details = Test-CollectionComparisonUsedAsAPredicate -Details

        $Details.Name | Should -Be 'CollectionComparisonUsedAsAPredicate'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Warning'
    }
}
