using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Parses a fixture and returns native empty-array member-access findings.
    #>
    function Invoke-EmptyMemberRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Errors | Should -BeNullOrEmpty
        Test-EmptyCollectionMemberAccess -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                OutputType = 'NitpickFinding'
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-EmptyCollectionMemberAccess' {
    It 'reports <Label>' -ForEach @(
        @{ Label = 'array-typed parameters'; Source = 'param([object[]] $Items) @($Items.Name)' }
        @{ Label = 'base array parameters'; Source = 'param([array] $Items) @($Items.Name)' }
        @{ Label = 'array cast'; Source = '@(([array] $Items).Name)' }
        @{ Label = 'typed array cast'; Source = '@(([object[]] $Items).Name)' }
        @{ Label = 'explicit empty array'; Source = '@(@().Name)' }
        @{ Label = 'unknown array expression cardinality'; Source = '@(@(Get-Item .).Name)' }
        @{ Label = 'array literal'; Source = '@((1, 2).Name)' }
        @{ Label = 'parenthesized receiver'; Source = 'param([object[]] $Items) @((($Items)).Name)' }
        @{ Label = 'parenthesized capture output'; Source = 'param([object[]] $Items) @(($Items.Name))' }
        @{ Label = 'quoted property'; Source = 'param([object[]] $Items) @($Items.''Display Name'')' }
        @{ Label = 'case-insensitive parameter lookup'; Source = 'param([object[]] $Items) @($items.Name)' }
    ) {
        $Findings = @(Invoke-EmptyMemberRule -Source $Source)
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/EmptyCollectionMemberAccess'
        $Findings[0].Severity | Should -Be 'Warning'
        $Findings[0].Message | Should -BeLike '*one null item*ForEach-Object*'
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'does not report <Label>' -ForEach @(
        @{ Label = 'unknown variables'; Source = '@($Items.Name)' }
        @{ Label = 'scalar string parameter'; Source = 'param([string] $Items) @($Items.Name)' }
        @{ Label = 'object parameter'; Source = 'param([object] $Items) @($Items.Name)' }
        @{ Label = 'hashtable parameter'; Source = 'param([hashtable] $Items) @($Items.Name)' }
        @{ Label = 'list parameter outside the current scope'; Source = 'param([System.Collections.Generic.List[object]] $Items) @($Items.Name)' }
        @{ Label = 'unknown property chain'; Source = 'param([object[]] $Items) @($Items.Children.Name)' }
        @{ Label = 'count'; Source = 'param([object[]] $Items) @($Items.Count)' }
        @{ Label = 'length'; Source = 'param([object[]] $Items) @($Items.length)' }
        @{ Label = 'rank'; Source = 'param([object[]] $Items) @($Items.Rank)' }
        @{ Label = 'interface property'; Source = 'param([object[]] $Items) @($Items.IsReadOnly)' }
        @{ Label = 'intrinsic member'; Source = 'param([object[]] $Items) @($Items.PSObject)' }
        @{ Label = 'method invocation'; Source = 'param([object[]] $Items) @($Items.GetType())' }
        @{ Label = 'dynamic property'; Source = 'param([object[]] $Items) @($Items.$Member)' }
        @{ Label = 'explicit projection'; Source = 'param([object[]] $Items) @($Items | ForEach-Object { $_.Name })' }
        @{ Label = 'redirected output'; Source = 'param([object[]] $Items) @($Items.Name > $null)' }
        @{ Label = 'transformed output'; Source = 'param([object[]] $Items) @($Items.Name + 42)' }
        @{ Label = 'multiple statements'; Source = 'param([object[]] $Items) @($Items.Name; 42)' }
        @{ Label = 'local array assignment without dataflow'; Source = '$Items = @(); @($Items.Name)' }
        @{ Label = 'qualified variable'; Source = 'param([object[]] $Items) @($global:Items.Name)' }
        @{ Label = 'receiver pipeline'; Source = '@((@() | Measure-Object).Name)' }
    ) {
        @(Invoke-EmptyMemberRule -Source $Source) | Should -HaveCount 0
    }

    It 'keeps inference lexical while honoring nested traversal' {
        $Source = 'param([object[]] $Items) & { @($Items.Name) }'
        @(Invoke-EmptyMemberRule -Source $Source -Recurse $true) | Should -HaveCount 0
        $Source = 'function Invoke-Example { param([object[]] $Items) @($Items.Name) }'
        @(Invoke-EmptyMemberRule -Source $Source) | Should -HaveCount 0
        @(Invoke-EmptyMemberRule -Source $Source -Recurse $true) | Should -HaveCount 1
    }

    It 'provides metadata and coordinated built-in findings' {
        $Details = Test-EmptyCollectionMemberAccess -Details
        $Details.Name | Should -Be 'EmptyCollectionMemberAccess'
        $Details.Category | Should -Be 'Correctness'
        $Rule = @(Find-Nitpick -IncludeRule Nitpick/EmptyCollectionMemberAccess)
        $Rule | Should -HaveCount 1
        $Source = 'param([object[]] $Items) @($Items.Name)'
        $Findings = @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/EmptyCollectionMemberAccess -Output Object -NoSummary)
        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.Text | Should -Be '@($Items.Name)'
        $Proposal = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Findings -Rule $Rule
        $Proposal.CandidateText | Should -BeExactly $Source
        $Proposal.AcceptedCorrections | Should -BeNullOrEmpty
    }

    It 'supports suppression' {
        $Source = 'param([object[]] $Items) @($Items.Name) # nitpick disable-line Nitpick/EmptyCollectionMemberAccess'
        @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/EmptyCollectionMemberAccess -Output Object -NoSummary) |
            Should -HaveCount 0
    }

    It 'reports nested ScriptAnalyzer findings once each' {
        $Source = 'param([object[]] $Items) @($Items.Name); function Invoke-Example { param([array] $Items) @($Items.Name) }'
        $Diagnostics = @(Invoke-ScriptAnalyzer -ScriptDefinition $Source `
            -CustomRulePath (Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1') `
            -IncludeRule Test-EmptyCollectionMemberAccess -Settings @{})
        $Diagnostics | Should -HaveCount 2
        foreach ($Diagnostic in $Diagnostics) {
            $Diagnostic.RuleName | Should -Be 'EmptyCollectionMemberAccess'
            $Diagnostic.RuleSuppressionID | Should -Be 'EmptyCollectionMemberAccess'
            $Diagnostic.SuggestedCorrections | Should -BeNullOrEmpty
        }
    }
}

Describe 'Empty-array member projection semantics' {
    It 'distinguishes empty receiver projection from explicit null property values' {
        $Empty = @()
        @($Empty.Name).Count | Should -Be 1
        @($Empty | ForEach-Object { $_.Name }).Count | Should -Be 0
        $One = @([pscustomobject]@{ Name = 'one' })
        @($One.Name).Count | Should -Be 1
        $Two = @([pscustomobject]@{ Name = 'one' }, [pscustomobject]@{ Name = 'two' })
        @($Two.Name).Count | Should -Be 2
        $NullProperty = @([pscustomobject]@{ Name = $null })
        $Projected = @($NullProperty | ForEach-Object { $_.Name })
        $Projected.Count | Should -Be 1
        ($null -eq $Projected[0]) | Should -BeTrue
    }
}
