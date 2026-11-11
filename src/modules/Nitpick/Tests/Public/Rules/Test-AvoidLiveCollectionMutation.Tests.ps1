using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Parses a fixture and returns native live-collection mutation findings.
    #>
    function Invoke-LiveCollectionRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Errors | Should -BeNullOrEmpty
        Test-AvoidLiveCollectionMutation -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                OutputType = 'NitpickFinding'
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-AvoidLiveCollectionMutation' {
    It 'reports <Label>' -ForEach @(
        @{ Label = 'the selected metadata loop'; Source = 'foreach ($Property in $ExecutionMetadata.Keys) { $ExecutionMetadata[$Property] = $Details.$Property }' }
        @{ Label = 'values view'; Source = 'foreach ($Value in $Map.Values) { $Map["key"] = 1 }' }
        @{ Label = 'conditional removal'; Source = 'foreach ($Key in $Map.Keys) { if ($Key) { $Map.Remove($Key) } }' }
        @{ Label = 'enumerator removal'; Source = 'foreach ($Entry in $Map.GetEnumerator()) { $Map.Remove($Entry.Key) }' }
        @{ Label = 'dictionary parameter index write'; Source = 'param([hashtable] $Map) foreach ($Entry in $Map) { $Map[$Entry.Key] = 2 }' }
        @{ Label = 'list parameter index write'; Source = 'param([System.Collections.Generic.List[object]] $Items) foreach ($Item in $Items) { $Items[0] = 2 }' }
        @{ Label = 'dictionary dot write'; Source = 'foreach ($Key in $Map.Keys) { $Map.Name = "changed" }' }
        @{ Label = 'dictionary compound assignment'; Source = 'foreach ($Key in $Map.Keys) { $Map[$Key] += 1 }' }
        @{ Label = 'dictionary postfix increment'; Source = 'foreach ($Key in $Map.Keys) { $Map[$Key]++ }' }
        @{ Label = 'dictionary prefix decrement'; Source = 'foreach ($Key in $Map.Keys) { --$Map[$Key] }' }
        @{ Label = 'list addition'; Source = 'foreach ($Item in $Items) { $Items.Add(2) }' }
        @{ Label = 'list removal'; Source = 'foreach ($Item in $Items) { $Items.RemoveAt(0) }' }
        @{ Label = 'collection clear'; Source = 'foreach ($Item in $Items) { $Items.Clear() }' }
        @{ Label = 'queue mutation'; Source = 'foreach ($Item in $Queue) { $Queue.Enqueue(2) }' }
        @{ Label = 'stack mutation'; Source = 'foreach ($Item in $Stack) { $Stack.Pop() }' }
        @{ Label = 'parenthesized receiver'; Source = 'foreach ($Key in (($Map).Keys)) { ($Map)[$Key] = 2 }' }
        @{ Label = 'case-insensitive receiver'; Source = 'foreach ($Key in $Map.Keys) { $map[$Key] = 2 }' }
        @{ Label = 'quoted member path'; Source = 'foreach ($Key in $State."Map".Keys) { $State.Map[$Key] = 2 }' }
        @{ Label = 'qualified receiver'; Source = 'foreach ($Key in $script:Map.Keys) { $script:Map[$Key] = 2 }' }
    ) {
        $Findings = @(Invoke-LiveCollectionRule -Source $Source)
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/AvoidLiveCollectionMutation'
        $Findings[0].Severity | Should -Be 'Warning'
        $Findings[0].Message | Should -BeLike '*snapshot*'
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'does not report <Label>' -ForEach @(
        @{ Label = 'keys snapshot'; Source = 'foreach ($Key in @($Map.Keys)) { $Map[$Key] = 2 }' }
        @{ Label = 'collection snapshot'; Source = 'foreach ($Item in @($Items)) { $Items.Add(2) }' }
        @{ Label = 'cloned keys'; Source = 'foreach ($Key in $Map.Keys.Clone()) { $Map.Remove($Key) }' }
        @{ Label = 'pipeline snapshot'; Source = 'foreach ($Key in ($Map.Keys | Sort-Object)) { $Map.Remove($Key) }' }
        @{ Label = 'array index write'; Source = 'param([object[]] $Items) foreach ($Item in $Items) { $Items[0] = 2 }' }
        @{ Label = 'array reassignment'; Source = 'foreach ($Item in $Items) { $Items += 2 }' }
        @{ Label = 'base array index write'; Source = 'param([array] $Items) foreach ($Item in $Items) { $Items[0]++ }' }
        @{ Label = 'unknown index receiver type'; Source = 'foreach ($Item in $Items) { $Items[0] = 2 }' }
        @{ Label = 'item property mutation'; Source = 'foreach ($Item in $Items) { $Item.Name = "changed" }' }
        @{ Label = 'another dictionary'; Source = 'foreach ($Key in $Map.Keys) { $Other[$Key] = 2; $Other.Remove($Key) }' }
        @{ Label = 'different member chain'; Source = 'foreach ($Key in $State.Map.Keys) { $State.Other[$Key] = 2 }' }
        @{ Label = 'read-only access'; Source = 'foreach ($Key in $Map.Keys) { $Map.ContainsKey($Key); $Value = $Map[$Key] }' }
        @{ Label = 'deferred scriptblock'; Source = 'foreach ($Key in $Map.Keys) { $Callback = { $Map.Clear() } }' }
        @{ Label = 'nested function'; Source = 'foreach ($Key in $Map.Keys) { function Invoke-Later { $Map.Clear() } }' }
        @{ Label = 'dynamic receiver'; Source = 'foreach ($Key in $State.$Name.Keys) { $State.$Name.Remove($Key) }' }
        @{ Label = 'dynamic method'; Source = 'foreach ($Item in $Items) { $Items.$Method() }' }
        @{ Label = 'hidden receiver'; Source = 'foreach ($Items in $Items) { $Items.Clear() }' }
        @{ Label = 'different qualification'; Source = 'foreach ($Key in $script:Map.Keys) { $Map.Remove($Key) }' }
        @{ Label = 'concurrent dictionary'; Source = 'param([System.Collections.Concurrent.ConcurrentDictionary[string,object]] $Map) foreach ($Item in $Map) { $Map.Clear() }' }
    ) {
        @(Invoke-LiveCollectionRule -Source $Source) | Should -HaveCount 0
    }

    It 'reports each mutation once even inside nested loops over the same collection' {
        $Source = 'foreach ($A in $Items) { foreach ($B in $Items) { $Items.Clear() } }'
        @(Invoke-LiveCollectionRule -Source $Source) | Should -HaveCount 1
    }

    It 'honors nested traversal without executing deferred mutations' {
        $Source = 'function Invoke-Example { foreach ($Key in $Map.Keys) { $Map[$Key] = 2; $Callback = { $Map.Clear() } } }'
        @(Invoke-LiveCollectionRule -Source $Source) | Should -HaveCount 0
        @(Invoke-LiveCollectionRule -Source $Source -Recurse $true) | Should -HaveCount 1
    }

    It 'provides metadata and coordinated findings at the mutation extent' {
        (Test-AvoidLiveCollectionMutation -Details).Category | Should -Be 'Correctness'
        @(Find-Nitpick -IncludeRule Nitpick/AvoidLiveCollectionMutation) | Should -HaveCount 1
        $Source = 'foreach ($Key in $Map.Keys) { $Map[$Key] = 2 }'
        $Findings = @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/AvoidLiveCollectionMutation -Output Object -NoSummary)
        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.Text | Should -Be '$Map[$Key] = 2'
    }

    It 'supports native suppression' {
        $Source = 'foreach ($Key in $Map.Keys) { $Map[$Key] = 2 } # nitpick disable-line Nitpick/AvoidLiveCollectionMutation'
        @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/AvoidLiveCollectionMutation -Output Object -NoSummary) |
            Should -HaveCount 0
    }

    It 'reports nested ScriptAnalyzer findings once each' {
        $Source = 'foreach ($Key in $Map.Keys) { $Map[$Key] = 2 }; function Invoke-Example { foreach ($Item in $Items) { $Items.Clear() } }'
        $Diagnostics = @(Invoke-ScriptAnalyzer -ScriptDefinition $Source `
            -CustomRulePath (Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1') `
            -IncludeRule Test-AvoidLiveCollectionMutation -Settings @{})
        $Diagnostics | Should -HaveCount 2
        foreach ($Diagnostic in $Diagnostics) {
            $Diagnostic.RuleName | Should -Be 'AvoidLiveCollectionMutation'
            $Diagnostic.SuggestedCorrections | Should -BeNullOrEmpty
        }
    }
}

Describe 'Live collection enumeration semantics' {
    It 'invalidates a live hashtable enumerator even when updating existing values' {
        $Map = @{ One = 1; Two = 2 }
        $Enumerator = $Map.Keys.GetEnumerator()
        $Enumerator.MoveNext() | Should -BeTrue
        $Map[$Enumerator.Current] = 3
        { $Enumerator.MoveNext() } | Should -Throw '*Collection was modified*'
    }

    It 'permits dictionary writes while enumerating a keys snapshot' {
        $Map = @{ One = 1; Two = 2 }
        foreach ($Key in @($Map.Keys)) { $Map[$Key] = 3 }
        $Map.One | Should -Be 3
        $Map.Two | Should -Be 3
    }

    It 'invalidates a list enumerator on <Label>' -ForEach @(
        @{ Label = 'addition'; Mutation = { param($Items) $Items.Add(3) } }
        @{ Label = 'index replacement'; Mutation = { param($Items) $Items[0] = 3 } }
    ) {
        $Items = [System.Collections.Generic.List[object]]::new()
        $Items.Add(1)
        $Items.Add(2)
        $Enumerator = $Items.GetEnumerator()
        $Enumerator.MoveNext() | Should -BeTrue
        & $Mutation $Items
        { $Enumerator.MoveNext() } | Should -Throw '*Collection was modified*'
    }

    It 'permits ordinary array writes and reassignment without invalidating the original enumerator' {
        $Items = @(1, 2)
        $Enumerator = $Items.GetEnumerator()
        $Enumerator.MoveNext() | Should -BeTrue
        $Items[1] = 3
        $Items += 4
        $Enumerator.MoveNext() | Should -BeTrue
        $Enumerator.Current | Should -Be 3
        $Enumerator.MoveNext() | Should -BeFalse
    }
}
