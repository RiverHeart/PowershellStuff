using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '..\..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Parses a rule fixture and returns native array-shape findings.
    #>
    function Invoke-ArrayShapeRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty
        Test-ArrayShapeLostThroughControlFlow -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                OutputType = 'NitpickFinding'
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-ArrayShapeLostThroughControlFlow' {
    It 'reports <Label> once per assigned if' -ForEach @(
        @{ Label = 'an empty array'; Source = '$Items = if ($Flag) { @() }' }
        @{ Label = 'typed array intent'; Source = '[array] $Items = if ($Flag) { @() }' }
        @{ Label = 'typed object array intent'; Source = '[object[]] $Items = if ($Flag) { @() }' }
        @{ Label = 'a singleton'; Source = '$Items = if ($Flag) { @(42) }' }
        @{ Label = 'a null item'; Source = '$Items = if ($Flag) { @($null) }' }
        @{ Label = 'multiple branches'; Source = '$Items = if ($Flag) { @(42) } elseif ($Other) { @($null) } else { @() }' }
        @{ Label = 'nested branch output'; Source = '$Items = if ($Flag) { if ($Other) { @() } }' }
        @{ Label = 'parenthesized output'; Source = '$Items = if ($Flag) { (@()) }' }
        @{ Label = 'comma-separated output'; Source = '$Items = if ($Flag) { 1, 2 }' }
        @{ Label = 'unknown cardinality'; Source = '$Items = if ($Flag) { @(Get-Item .) }' }
        @{ Label = 'nonfinal output'; Source = '$Items = if ($Flag) { @(); Write-Output 42 }' }
    ) {
        $Findings = @(Invoke-ArrayShapeRule -Source $Source)
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/ArrayShapeLostThroughControlFlow'
        $Findings[0].Severity | Should -Be 'Warning'
        $Findings[0].Message | Should -BeExactly 'Arrays emitted by this if lose their shape before assignment.'
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'does not report <Label>' -ForEach @(
        @{ Label = 'outer capture'; Source = '$Items = @(if ($Flag) { @() } else { @(42) })' }
        @{ Label = 'unary comma protection'; Source = '$Items = if ($Flag) { ,@() } else { ,@(42) }' }
        @{ Label = 'a local assignment'; Source = '$Items = if ($Flag) { $Local = @() }' }
        @{ Label = 'discarded output'; Source = '$Items = if ($Flag) { [void] @() }' }
        @{ Label = 'a command argument'; Source = '$Items = if ($Flag) { Write-Output -NoEnumerate @() }' }
        @{ Label = 'an array used in a condition'; Source = '$Items = if (@().Count -eq 0) { 42 }' }
        @{ Label = 'a nested condition'; Source = '$Items = if ($Flag) { if (@().Count -eq 0) { 42 } }' }
        @{ Label = 'redirected output'; Source = '$Items = if ($Flag) { @() > $null }' }
        @{ Label = 'a pipeline transformation'; Source = '$Items = if ($Flag) { @() | Measure-Object }' }
        @{ Label = 'return control flow'; Source = '$Items = if ($Flag) { return @() }' }
        @{ Label = 'an uninvoked scriptblock'; Source = '$Items = if ($Flag) { { @() } }' }
        @{ Label = 'variable output without dataflow'; Source = '$Items = if ($Flag) { $Local = @(); $Local }' }
        @{ Label = 'direct array initialization'; Source = '$Items = @()' }
        @{ Label = 'null destination'; Source = '$null = if ($Flag) { @() }' }
        @{ Label = 'member destination'; Source = '$Object.Items = if ($Flag) { @() }' }
        @{ Label = 'compound assignment'; Source = '$Items += if ($Flag) { @() }' }
    ) {
        @(Invoke-ArrayShapeRule -Source $Source) | Should -HaveCount 0
    }

    It 'respects nested scriptblock traversal' {
        $Source = 'function Invoke-Example { $Items = if ($Flag) { @() } }'
        @(Invoke-ArrayShapeRule -Source $Source) | Should -HaveCount 0
        @(Invoke-ArrayShapeRule -Source $Source -Recurse $true) | Should -HaveCount 1
    }

    It 'provides metadata and built-in discovery' {
        $Details = Test-ArrayShapeLostThroughControlFlow -Details
        $Details.Name | Should -Be 'ArrayShapeLostThroughControlFlow'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Warning'
        $Details.Explanation | Should -BeLike '*the result may be null, a scalar, or an array*'
        $Details.Explanation | Should -BeLike '*empty @() emits no items*'
        $Details.Explanation | Should -Match 'typing the destination as \[array\] does not fix absent output'
        $Details.Explanation | Should -BeLike '*Initialize the destination collection separately*'
        $Details.Explanation | Should -BeLike '*Preserve explicit null items*'
        @(Find-Nitpick -IncludeRule Nitpick/ArrayShapeLostThroughControlFlow) | Should -HaveCount 1
    }

    It 'reports coordinated native findings and offers no source-changing correction' {
        $Source = '$Items = if ($Flag) { @() }'
        $Results = @(Start-Nitpicking `
            -Script $Source `
            -IncludeRule Nitpick/ArrayShapeLostThroughControlFlow `
            -Output Object `
            -NoSummary
        )

        $Results | Should -HaveCount 1
        $Results[0].RuleId | Should -Be 'Nitpick/ArrayShapeLostThroughControlFlow'
        $Results[0].ViolationExtent.Text | Should -Be 'if ($Flag) { @() }'

        $Rule = @(Find-Nitpick -IncludeRule Nitpick/ArrayShapeLostThroughControlFlow)
        $Proposal = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Results -Rule $Rule
        $Proposal.CandidateText | Should -BeExactly $Source
        $Proposal.AcceptedCorrections | Should -BeNullOrEmpty
    }

    It 'supports line suppression' {
        $Source = '$Items = if ($Flag) { @() } # nitpick disable-line Nitpick/ArrayShapeLostThroughControlFlow'
        @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/ArrayShapeLostThroughControlFlow -Output Object -NoSummary) |
            Should -HaveCount 0
    }

    It 'returns ScriptAnalyzer diagnostics without duplicated nested findings' {
        $Source = @'
$Items = if ($Flag) { @() }
function Invoke-Example {
    $Items = if ($Flag) { @($null) } else { @(42) }
}
'@
        $Diagnostics = @(Invoke-ScriptAnalyzer -ScriptDefinition $Source `
            -CustomRulePath (Join-Path $PSScriptRoot '..\..\..\..\Nitpick.psd1') `
            -IncludeRule Test-ArrayShapeLostThroughControlFlow -Settings @{})
        $Diagnostics | Should -HaveCount 2
        foreach ($Diagnostic in $Diagnostics) {
            $Diagnostic.GetType().Name | Should -Be 'DiagnosticRecord'
            $Diagnostic.RuleName | Should -Be 'ArrayShapeLostThroughControlFlow'
            $Diagnostic.RuleSuppressionID | Should -Be 'ArrayShapeLostThroughControlFlow'
            $Diagnostic.SuggestedCorrections | Should -BeNullOrEmpty
        }
    }
}

Describe 'Array output shape reproductions' {
    It 'loses empty and singleton array shapes through bare if assignment' {
        $Empty = if ($true) { @() }
        $Single = if ($true) { @(42) }
        [array] $TypedEmpty = if ($true) { @() }
        ($null -eq $Empty) | Should -BeTrue
        ($null -eq $TypedEmpty) | Should -BeTrue
        $Single.GetType() | Should -Be ([int])
    }

    It 'keeps collection identity while populating only emitted items' {
        $Items = [System.Collections.Generic.List[object]]::new()
        $Original = $Items
        $(if ($true) { @() }) | ForEach-Object { $Items.Add($_) }
        $Items.Count | Should -Be 0
        $(if ($true) { @($null) }) | ForEach-Object { $Items.Add($_) }
        $Items.Count | Should -Be 1
        ($null -eq $Items[0]) | Should -BeTrue
        [object]::ReferenceEquals($Items, $Original) | Should -BeTrue
    }

    It 'distinguishes missing-key null output from absent output' {
        $Map = @{}
        @($Map['Missing']).Count | Should -Be 1
        @(if ($Map.ContainsKey('Missing')) { $Map['Missing'] }).Count | Should -Be 0
    }
}
