using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Parses a fixture and invokes the indexed-lookup rule.
    #>
    function Invoke-IndexedLookupRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty
        Test-PossibleNullItemFromIndexedLookup -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                OutputType = 'NitpickFinding'
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-PossibleNullItemFromIndexedLookup' {
    It 'reports <Label> as an intent warning' -ForEach @(
        @{ Label = 'an unknown indexed object'; Source = '$Items = @($Map[''Key''])' }
        @{ Label = 'self assignment'; Source = '$foo = @($foo[''bar''])' }
        @{ Label = 'a numeric index'; Source = '$Items = @($Values[0])' }
        @{ Label = 'a dynamic index'; Source = '$Items = @($Map[$Key])' }
        @{ Label = 'a literal hashtable'; Source = '$Items = @(@{}[''Missing''])' }
        @{ Label = 'parentheses'; Source = '$Items = @(($Map[''Key'']))' }
        @{ Label = 'nested parentheses'; Source = '$Items = @((($Map[''Key''])))' }
        @{ Label = 'array destination typing'; Source = '[array] $Items = @($Map[''Key''])' }
        @{ Label = 'object destination typing'; Source = '[object] $Items = @($Map[''Key''])' }
        @{ Label = 'object expression casting'; Source = '$Items = [object] @($Map[''Key''])' }
        @{ Label = 'a count demonstration'; Source = '@($Map[''Key'']).Count' }
        @{ Label = 'a command argument'; Source = 'Write-Output @($Map[''Key''])' }
    ) {
        $Findings = @(Invoke-IndexedLookupRule -Source $Source)
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/PossibleNullItemFromIndexedLookup'
        $Findings[0].Severity | Should -Be 'Information'
        $Findings[0].ViolationExtent.Text | Should -BeLike '@(*'
        $Findings[0].Message | Should -BeLike '*If this indexed lookup returns $null*one null item*ContainsKey()*'
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'does not report <Label>' -ForEach @(
        @{ Label = 'plain indexing'; Source = '$Items = $Map[''Key'']' }
        @{ Label = 'empty capture'; Source = '$Items = @()' }
        @{ Label = 'a scalar variable'; Source = '$Items = @($Value)' }
        @{ Label = 'an explicit null'; Source = '$Items = @($null)' }
        @{ Label = 'a presence guard'; Source = '$Items = @(if ($Map.ContainsKey(''Key'')) { $Map[''Key''] })' }
        @{ Label = 'null filtering'; Source = '$Items = @($Map[''Key''] | Where-Object { $null -ne $_ })' }
        @{ Label = 'multiple output statements'; Source = '$Items = @($Map[''Key'']; 42)' }
        @{ Label = 'comma-separated output'; Source = '$Items = @($Map[''Key''], 42)' }
        @{ Label = 'a transformed expression'; Source = '$Items = @($Map[''Key''] + 42)' }
        @{ Label = 'a member access'; Source = '$Items = @($Map[''Key''].Name)' }
        @{ Label = 'a command consuming the lookup'; Source = '$Items = @(Write-Output $Map[''Key''])' }
        @{ Label = 'redirected output'; Source = '$Items = @($Map[''Key''] > $null)' }
        @{ Label = 'parenthesized transformed output'; Source = '$Items = @(($Map[''Key''] | Measure-Object))' }
        @{ Label = 'a local assignment'; Source = '$Items = @($Local = $Map[''Key''])' }
    ) {
        @(Invoke-IndexedLookupRule -Source $Source) | Should -HaveCount 0
    }

    It 'respects nested scriptblock traversal and reports each capture once' {
        $Source = 'function Invoke-Example { $Items = @($Map[''Key'']) }'
        @(Invoke-IndexedLookupRule -Source $Source) | Should -HaveCount 0
        @(Invoke-IndexedLookupRule -Source $Source -Recurse $true) | Should -HaveCount 1
        @(Invoke-IndexedLookupRule -Source '$a = @($Map[0]); $b = @($Map[1])') | Should -HaveCount 2
    }

    It 'supports metadata, discovery and coordinated identity' {
        $Details = Test-PossibleNullItemFromIndexedLookup -Details
        $Details.Name | Should -Be 'PossibleNullItemFromIndexedLookup'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Information'
        @(Find-Nitpick -IncludeRule Nitpick/PossibleNullItemFromIndexedLookup) | Should -HaveCount 1

        $Findings = @(Start-Nitpicking -Script '$Items = @($Map[''Key''])' `
            -IncludeRule Nitpick/PossibleNullItemFromIndexedLookup -Output Object -NoSummary)
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/PossibleNullItemFromIndexedLookup'
    }

    It 'supports explicit suppression for intentional null capture' {
        $Source = '$Items = @($Map[''Key'']) # nitpick disable-line Nitpick/PossibleNullItemFromIndexedLookup -- Null is intentional.'
        @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/PossibleNullItemFromIndexedLookup `
            -Output Object -NoSummary) | Should -HaveCount 0
    }

    It 'offers no automatic null filtering or source changes' {
        $Source = '$Items = @($Map[''Key''])'
        $Findings = @(Invoke-IndexedLookupRule -Source $Source)
        $Rule = @(Find-Nitpick -IncludeRule Nitpick/PossibleNullItemFromIndexedLookup)
        $Proposal = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Findings -Rule $Rule
        $Proposal.CandidateText | Should -BeExactly $Source
        $Proposal.AcceptedCorrections | Should -BeNullOrEmpty
    }

    It 'returns ScriptAnalyzer diagnostics exactly once per nested capture' {
        $Source = '$Items = @($Map[0]); function Invoke-Example { $Items = @($Map[1]) }'
        $Diagnostics = @(Invoke-ScriptAnalyzer -ScriptDefinition $Source `
            -CustomRulePath (Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1') `
            -IncludeRule Test-PossibleNullItemFromIndexedLookup -Settings @{})
        $Diagnostics | Should -HaveCount 2
        foreach ($Diagnostic in $Diagnostics) {
            $Diagnostic.GetType().Name | Should -Be 'DiagnosticRecord'
            $Diagnostic.RuleName | Should -Be 'PossibleNullItemFromIndexedLookup'
            $Diagnostic.RuleSuppressionID | Should -Be 'PossibleNullItemFromIndexedLookup'
            $Diagnostic.Severity.ToString() | Should -Be 'Information'
            $Diagnostic.SuggestedCorrections | Should -BeNullOrEmpty
        }
    }
}

Describe 'Indexed lookup null semantics' {
    It 'captures missing-key nulls and preserves present nulls under a presence guard' {
        $Map = @{}
        $Missing = @($Map['Key'])
        $Missing.Count | Should -Be 1
        ($null -eq $Missing[0]) | Should -BeTrue
        @(if ($Map.ContainsKey('Key')) { $Map['Key'] }).Count | Should -Be 0

        $Map['Key'] = $null
        $Present = @(if ($Map.ContainsKey('Key')) { $Map['Key'] })
        $Present.Count | Should -Be 1
        ($null -eq $Present[0]) | Should -BeTrue
    }
}
