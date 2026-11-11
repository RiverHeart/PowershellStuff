using module AstEditor

BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'NitpickRule' {
    It 'distinguishes an inapplicable outcome from an empty execution' {
        $Rule = New-Nitpick -Name Empty -Source Tests -Callable { param($ScriptBlockAst) }
        $Document = New-AstDocument -InputObject '# empty'
        $Outcome = $Rule.InvokeWithResult($Document, @{})
        $Outcome.GetType().Name | Should -BeExactly 'NitpickRuleInvocationResult'
        $Outcome.Status | Should -BeExactly 'Executed'
        $Outcome.Results.GetType() | Should -Be ([object[]])
        $Outcome.Results.Count | Should -Be 0

        $Rule.Applicability = { $false }
        $Outcome = $Rule.InvokeWithResult(@{ ScriptBlockAst = $Document.Ast })
        $Outcome.Status | Should -BeExactly 'Inapplicable'
        $Outcome.Results.GetType() | Should -Be ([object[]])
        $Outcome.Results.Count | Should -Be 0
        $Rule.Invoke($Document).Count | Should -Be 0
    }

    It 'evaluates applicability once per dispatch across all entry points for <ProducerType>' -ForEach @(
        @{ ProducerType = 'Legacy' }
        @{ ProducerType = 'TypedAst' }
        @{ ProducerType = 'Document' }
    ) {
        $State = @{ Predicates = 0; Producers = 0 }
        $Predicate = {
            param([System.Collections.IDictionary] $Context)
            $State.Predicates++
            $Context.TargetKind -eq 'Fragment'
        }.GetNewClosure()

        $Producer = switch ($ProducerType) {
            Legacy {
                {
                    param($ScriptBlockAst)
                    $State.Producers++;
                    $ScriptBlockAst
                }.GetNewClosure()
            }
            TypedAst {
                {
                    param([System.Management.Automation.Language.ScriptBlockAst] $InputObject)
                    $State.Producers++
                    $InputObject
                }.GetNewClosure()
            }
            Document {
                {
                    param([AstDocument] $Document)
                    $State.Producers++;
                    $Document
                }.GetNewClosure()
            }
        }

        $Rule = New-Nitpick `
            -Name Counted `
            -Source Tests `
            -Callable $Producer `
            -Applicability $Predicate

        $Document = New-AstDocument -InputObject '# text'
        $Ast = $Document.Ast
        $Parameters = @{ Context = @{} }
        $Parameters[$Rule.DispatchParameterName] = $Document
        $Calls = @(
            { $Rule.Invoke($Ast) },
            { $Rule.Invoke($Ast, @{}) },
            { $Rule.Invoke($Document) },
            { $Rule.Invoke($Document, @{}) },
            { $Rule.Invoke($Parameters) },
            { $Rule.Invoke(@{ ScriptBlockAst = $Ast }) },
            { $Rule.InvokeWithResult($Document, @{}).Results },
            { $Rule.InvokeWithResult($Ast, @{}).Results },
            { $Rule.InvokeWithResult($Parameters).Results }
        )

        foreach ($Call in $Calls) {
            $Result = @(& $Call)
            $Result.Count | Should -Be 1

            if ($ProducerType -eq 'Document') {
                $Result[0].OriginalText | Should -BeExactly $Document.OriginalText
            } else {
                [object]::ReferenceEquals($Result[0], $Ast) | Should -BeTrue
            }
        }

        $State.Predicates | Should -Be $Calls.Count
        $State.Producers | Should -Be $Calls.Count

        $Rule.Applicability = { $State.Predicates++; $false }.GetNewClosure()
        foreach ($Call in $Calls) { @(& $Call).Count | Should -Be 0 }
        $State.Predicates | Should -Be ($Calls.Count * 2)
        $State.Producers | Should -Be $Calls.Count
    }

    It 'rejects <Kind> predicate output without invoking the producer' -ForEach @(
        @{ Kind = 'missing'; Predicate = {} }
        @{ Kind = 'null'; Predicate = { $null } }
        @{ Kind = 'multiple'; Predicate = { $true; $false } }
        @{ Kind = 'string'; Predicate = { 'false' } }
        @{ Kind = 'integer'; Predicate = { 1 } }
        @{ Kind = 'object'; Predicate = { [pscustomobject]@{ Applicable = $true } } }
        @{ Kind = 'unrolled-array'; Predicate = { ,@($true) } }
        @{ Kind = 'stray output'; Predicate = { 'trace'; $true } }
    ) {
        $State = @{ Predicates = 0; Producers = 0 }
        $CountedPredicate = {
            param([System.Collections.IDictionary] $Context)
            $State.Predicates++
            & $Predicate $Context
        }.GetNewClosure()

        $Callable = {
            param($ScriptBlockAst)
            $State.Producers++
        }.GetNewClosure()

        $Rule = New-Nitpick `
            -Name InvalidOutput `
            -Source Tests `
            -Callable $Callable `
            -Applicability $CountedPredicate `
            -MinimumAnalysisHostVersion ([version] '999.0')

        { $Rule.InvokeWithResult(@{ ScriptBlockAst = {}.Ast }) } |
            Should -Throw '*Local/InvalidOutput*' -ErrorId '*NitpickInvalidApplicabilityResult*'

        $State.Predicates | Should -Be 1
        $State.Producers | Should -Be 0
    }

    It 'terminates on <Kind> predicate errors and preserves their cause' -ForEach @(
        @{ Kind = 'throwing'; Predicate = { throw [InvalidOperationException]::new('predicate sentinel') } }
        @{ Kind = 'non-terminating'; Predicate = { Write-Error 'predicate sentinel'; $true } }
        @{ Kind = 'explicit continue'; Predicate = { Write-Error 'predicate sentinel' -ErrorAction Continue; $true } }
    ) {
        $State = @{ Predicates = 0; Producers = 0 }
        $CountedPredicate = {
            param([System.Collections.IDictionary] $Context)
            $State.Predicates++
            & $Predicate $Context
        }.GetNewClosure()

        $Callable = {
            param($ScriptBlockAst)
            $State.Producers++
        }.GetNewClosure()

        $Rule = New-Nitpick `
            -Name FailedPredicate `
            -Source Tests `
            -Callable $Callable `
            -Applicability $CountedPredicate

        $Caught = $null
        try {
            $null = $Rule.Invoke({}.Ast)
        } catch {
            $Caught = $_
        }

        $Caught | Should -Not -BeNullOrEmpty
        $Caught.FullyQualifiedErrorId | Should -BeLike '*NitpickApplicabilityFailed*'
        $Caught.Exception.Message | Should -BeLike '*Local/FailedPredicate*predicate sentinel*'
        $Caught.Exception.InnerException | Should -Not -BeNullOrEmpty
        $State.Predicates | Should -Be 1
        $State.Producers | Should -Be 0
    }

    It 'checks host requirements only after applicability and against the actual host' {
        $State = @{ Predicates = 0; Producers = 0 }
        $Predicate = { $State.Predicates++; $false }.GetNewClosure()
        $Callable = {
            param($ScriptBlockAst)
            $State.Producers++
            'raw'
        }.GetNewClosure()

        $Rule = New-Nitpick `
            -Name FutureHost `
            -Source Tests `
            -Callable $Callable `
            -Applicability $Predicate `
            -MinimumAnalysisHostVersion ([version] '999.0')

        $Outcome = $Rule.InvokeWithResult({}.Ast, @{})
        $Outcome.Status | Should -BeExactly 'Inapplicable'
        $State.Predicates | Should -Be 1
        $State.Producers | Should -Be 0

        $Rule.Applicability = { $State.Predicates++; $true }.GetNewClosure()
        { $Rule.InvokeWithResult({}.Ast, @{}) } |
            Should -Throw '*Local/FutureHost*999.0*actual host*' -ErrorId '*NitpickUnsupportedAnalysisHost*'

        $State.Predicates | Should -Be 2
        $State.Producers | Should -Be 0

        $Rule.Applicability = $null
        { $Rule.Invoke({}.Ast) } | Should -Throw -ErrorId '*NitpickUnsupportedAnalysisHost*'

        $State.Producers | Should -Be 0
        $PSVersion = $PSVersionTable.PSVersion
        $Rule.MinimumAnalysisHostVersion = [version]::new($PSVersion.Major, $PSVersion.Minor)
        $Rule.Invoke({}.Ast)[0] | Should -BeExactly 'raw'
        $State.Producers | Should -Be 1
    }

    It 'validates target and context before invoking a predicate' {
        $State = @{ Predicates = 0; Producers = 0 }
        $Predicate = { $State.Predicates++; $false }.GetNewClosure()
        $Callable = { param($ScriptBlockAst) $State.Producers++ }.GetNewClosure()

        $Rule = New-Nitpick `
            -Name ValidateFirst `
            -Source Tests `
            -Callable $Callable `
            -Applicability $Predicate

        { $Rule.InvokeWithResult(@{ ScriptBlockAst = 'invalid' }) } |
            Should -Throw '*ScriptBlockAst*'

        { $Rule.InvokeWithResult({}.Ast, @{ Extra = [pscustomobject]@{} }) } |
            Should -Throw -ErrorId '*NitpickInvalidContext*'

        $State.Predicates | Should -Be 0
        $State.Producers | Should -Be 0
    }

    It 'does not allow a predicate to alter authoritative host prerequisites' {
        $Predicate = {
            param([System.Collections.IDictionary] $Context)
            $Context.AnalysisHost.PowerShellVersion = [version] '999.0'
            $true
        }

        $Callable = {
            param($ScriptBlockAst)
            throw 'producer must not execute'
        }

        $Rule = New-Nitpick `
            -Name ActualHost `
            -Source Tests `
            -Callable $Callable `
            -MinimumAnalysisHostVersion ([version] '999.0') `
            -Applicability $Predicate

        { $Rule.InvokeWithResult({}.Ast, @{}) } |
            Should -Throw -ErrorId '*NitpickUnsupportedAnalysisHost*'
    }

    It 'preserves native attribution and non-native output through outcomes' {
        $Ast = { -not ($Value -is [string]) }.Ast
        $Rule = New-Nitpick `
            -Callable Test-UseIsNotOperator `
            -Namespace OutcomeOwner `
            -Applicability { $true }

        $Outcome = $Rule.InvokeWithResult($Ast, @{})
        $Outcome.Status | Should -BeExactly 'Executed'
        $Outcome.Results.Count | Should -Be 1
        $Outcome.Results[0].RuleId | Should -BeExactly 'OutcomeOwner/UseIsNotOperator'
        $Outcome.Results[0].Corrections[0].RuleId | Should -BeExactly 'OutcomeOwner/UseIsNotOperator'

        $Outcome = $Rule.InvokeWithResult($Ast, @{ RuleBehavior = @{ OutputType = 'DiagnosticRecord' } })
        $Outcome.Results[0].GetType().Name | Should -BeExactly 'DiagnosticRecord'
    }

    It 'isolates predicate and producer mutation from each other, caller input, and defaults' {
        $State = @{ Predicates = 0 }
        $Predicate = {
            param([System.Collections.IDictionary] $Context)

            $State.Predicates++
            $Context.Policy.Compatibility.PowerShell.MinimumVersion = [version] '7.4'
            $Context.Extra.Values[0] = 9
            $Context.RuleBehavior.OutputType = 'DiagnosticRecord'
            $Context |
                Add-Member -NotePropertyName Caller -NotePropertyValue 'shadow' -Force
            $Context.AnalysisHost.PowerShellVersion |
                Add-Member -NotePropertyName Marker -NotePropertyValue 1
            $true
        }.GetNewClosure()

        $Callable = {
            param(
                [AstDocument] $Document,
                [System.Collections.IDictionary] $Context
            )

            $Snapshot = [pscustomobject]@{
                Minimum = $Context.Policy.Compatibility.PowerShell.MinimumVersion
                Extra = $Context.Extra.Values[0]
                OutputType = $Context.RuleBehavior.OutputType
                Caller = $Context.Caller
                HostMarker = $Context.AnalysisHost.PowerShellVersion.psobject.Properties['Marker']
            }
            $Context.Policy.Compatibility.PowerShell.MinimumVersion = [version] '7.5'
            $Context.Extra.Values[0] = 8
            $Snapshot
        }

        $Rule = New-Nitpick `
            -Name Isolated `
            -Source Tests `
            -Callable $Callable `
            -Applicability $Predicate

        $Context = @{
            Policy = @{ Compatibility = @{ PowerShell = @{ MinimumVersion = '5.1' } } }
            Extra = @{ Values = @(1) }
        }
        $Document = New-AstDocument -InputObject '# text'

        foreach ($Index in 1..2) {
            $Outcome = $Rule.InvokeWithResult($Document, $Context)
            $Outcome.Status | Should -BeExactly 'Executed'
            $Value = $Outcome.Results[0]
            $Value.Minimum | Should -Be ([version] '5.1')
            $Value.Extra | Should -Be 1
            $Value.OutputType | Should -BeExactly 'NitpickFinding'
            $Value.Caller | Should -BeExactly 'Nitpick'
            $Value.HostMarker | Should -BeNullOrEmpty
        }

        $State.Predicates | Should -Be 2
        $Context.Policy.Compatibility.PowerShell.MinimumVersion | Should -BeExactly '5.1'
        $Context.Extra.Values[0] | Should -Be 1
        $Context.Contains('RuleBehavior') | Should -BeFalse
    }

    It 'dispatches an AstDocument directly and keeps it out of Context' {
        #=== Arrange ===#
        $Rule = New-Nitpick -Name DocumentContext -Source Tests -Callable {
            param(
                [AstDocument] $Document,
                [System.Collections.IDictionary] $Context
            )
            [pscustomobject]@{ Document = $Document; Context = $Context }
        }
        $Document = New-AstDocument -InputObject '# text'
        $Context = @{ Extra = @{ Values = @(1, 2) } }

        #=== Act ===#
        $Result = @($Rule.Invoke($Document, $Context))[0]

        #=== Assert ===#
        $Rule.DispatchType | Should -Be ([AstDocument])
        [object]::ReferenceEquals($Result.Document, $Document) | Should -BeTrue
        [object]::ReferenceEquals($Result.Context, $Context) | Should -BeFalse
        $Result.Context.Extra.Values | Should -Be @(1, 2)
        $Result.Context.Extra.Values[0] = 9
        $Context.Extra.Values[0] | Should -Be 1
        $Context.Contains('Caller') | Should -BeFalse
        $Context.Contains('Document') | Should -BeFalse
    }

    It 'supports AstDocument dispatch from AST-only and dictionary invocation' {
        #=== Arrange ===#
        $Rule = New-Nitpick -Name DocumentContext -Source Tests -Callable {
            param(
                [AstDocument] $Document
            )
            $Document
        }
        $Document = New-AstDocument -InputObject '# text'
        $Ast = $Document.Ast

        #=== Act ===#
        $Direct = @($Rule.Invoke($Ast))[0]
        $Dictionary = @($Rule.Invoke(@{ Document = $Document }))[0]

        #=== Assert ===#
        $Direct.OriginalText | Should -BeExactly '# text'
        [object]::ReferenceEquals($Dictionary, $Document) | Should -BeTrue
    }

    It 'isolates every invocation from producer mutations and ETS shadowing' {
        $Rule = New-Nitpick -Name MutatingContext -Source Tests -Callable {
            param(
                [System.Management.Automation.Language.ScriptBlockAst] $InputObject,
                [System.Collections.IDictionary] $Context
            )
            $Original = $Context.Policy.Compatibility.PowerShell.MinimumVersion
            $Context.Policy.Compatibility.PowerShell.MinimumVersion = [version] '7.4'
            $Context.Extra.Values[0] = 9
            Add-Member -InputObject $Context -NotePropertyName Caller -NotePropertyValue 'shadow' -Force
            $Original
        }
        $Context = @{
            Policy = @{ Compatibility = @{ PowerShell = @{ MinimumVersion = '5.1' } } }
            Extra = @{ Values = @(1) }
        }
        $Ast = {}.Ast
        $Document = New-AstDocument -InputObject $Ast
        foreach ($Results in @(
            $Rule.Invoke($Ast, $Context),
            $Rule.Invoke($Document, $Context),
            $Rule.Invoke(@{ InputObject = $Ast; Context = $Context }),
            $Rule.Invoke(@{ ScriptBlockAst = $Ast; Context = $Context })
        )) {
            $Results[0] | Should -Be ([version] '5.1')
        }
        $Context.Policy.Compatibility.PowerShell.MinimumVersion | Should -BeExactly '5.1'
        $Context.Extra.Values[0] | Should -Be 1
        $Context.Contains('Caller') | Should -BeFalse
    }

    It 'preserves file identity when a document is dispatched to an AST producer' {
        $Rule = New-Nitpick -Name FileIdentity -Source Tests -Callable {
            param(
                [System.Management.Automation.Language.ScriptBlockAst] $InputObject,
                [System.Collections.IDictionary] $Context
            )
            [pscustomobject]@{ Ast = $InputObject; Context = $Context }
        }
        $Path = Join-Path $TestDrive 'identity.ps1'
        Set-Content -LiteralPath $Path -Value '# text'
        $Document = New-AstDocument -Path $Path
        foreach ($Result in @(
            $Rule.Invoke($Document),
            $Rule.Invoke($Document, @{}),
            $Rule.Invoke(@{ InputObject = $Document })
        )) {
            [object]::ReferenceEquals($Result.Ast, $Document.Ast) | Should -BeTrue
            $Result.Context.TargetKind | Should -BeExactly 'File'
            $Result.Context.TargetPath | Should -BeExactly $Document.Path
        }
        $Fragment = $Rule.Invoke($Document.Ast, @{})[0]
        $Fragment.Context.TargetKind | Should -BeExactly 'Fragment'
        $Fragment.Context.TargetPath | Should -BeNullOrEmpty
    }

    It 'validates context even when a producer does not accept it' {
        $Rule = New-Nitpick -Name NoContext -Source Tests -Callable {
            param([System.Management.Automation.Language.ScriptBlockAst] $InputObject)
            'unchanged'
        }
        { $Rule.Invoke({}.Ast, @{ Extra = [pscustomobject]@{} }) } |
            Should -Throw -ErrorId '*NitpickInvalidContext*'
        $Rule.Invoke({}.Ast, @{ Extra = @(1, 2) })[0] | Should -BeExactly 'unchanged'
    }

    It 'dispatches typed ScriptBlockAst parameters under their declared name' {
        $Rule = New-Nitpick -Name TypedAst -Source Tests -Callable {
            param(
                [System.Management.Automation.Language.ScriptBlockAst] $InputObject
            )
            $InputObject
        }
        $Ast = { '$value' }.Ast

        $Result = @($Rule.Invoke($Ast))[0]

        $Rule.DispatchType | Should -Be ([System.Management.Automation.Language.ScriptBlockAst])
        $Rule.DispatchParameterName | Should -BeExactly 'InputObject'
        [object]::ReferenceEquals($Result, $Ast) | Should -BeTrue
    }

    It 'preserves the legacy ScriptBlockAst name fallback for untyped and object parameters' {
        foreach ($Callable in @(
            { param ($ScriptBlockAst) $ScriptBlockAst },
            { param ([object] $ScriptBlockAst) $ScriptBlockAst }
        )) {
            $Rule = New-Nitpick -Name LegacyAst -Source Tests -Callable $Callable
            $Ast = { '$value' }.Ast

            $Result = @($Rule.Invoke($Ast))[0]

            $Rule.DispatchType | Should -Be ([System.Management.Automation.Language.ScriptBlockAst])
            [object]::ReferenceEquals($Result, $Ast) | Should -BeTrue
        }
    }

    It 'rejects incompatible types declared on the legacy parameter name' {
        {
            New-Nitpick -Name InvalidAst -Source Tests -Callable {
                param ([string] $ScriptBlockAst)
            }
        } | Should -Throw "*Parameter 'ScriptBlockAst'*"
    }

    It 'rejects callable parameters outside the dispatch, Context, and Details contract' {
        {
            New-Nitpick -Name ExtraParameter -Source Tests -Callable {
                param (
                    [System.Management.Automation.Language.ScriptBlockAst] $InputObject,
                    [string] $Configuration
                )
            }
        } | Should -Throw "*Unsupported parameter 'Configuration'*"
    }

    It 'rejects Context parameters that cannot bind with the dispatch parameter' {
        {
            New-Nitpick -Name SeparateContextSet -Source Tests -Callable {
                [CmdletBinding()]
                param(
                    [Parameter(Mandatory,ParameterSetName='Rule')]
                    [System.Management.Automation.Language.ScriptBlockAst] $InputObject,

                    [Parameter(ParameterSetName='Context')]
                    [System.Collections.IDictionary] $Context
                )
            }
        } | Should -Throw '*Context and the dispatch parameter must share an ordinary parameter set*'
    }

    It 'requires Details to be mandatory in its own parameter set' {
        {
            New-Nitpick -Name OptionalDetails -Source Tests -Callable {
                [CmdletBinding(DefaultParameterSetName='Rule')]
                param(
                    [Parameter(Mandatory,ParameterSetName='Rule')]
                    [System.Management.Automation.Language.ScriptBlockAst] $InputObject,

                    [Parameter(ParameterSetName='Details')]
                    [switch] $Details
                )
            }
        } | Should -Throw '*Details must be mandatory in one separate parameter set*'
    }

    It 'rejects callables with more than one dispatch parameter' {
        {
            New-Nitpick -Name Ambiguous -Source Tests -Callable {
                param(
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,
                    [AstDocument] $Document
                )
            }
        } | Should -Throw '*exactly one dispatch parameter*'
    }

    It 'returns no findings when the callable emits no output' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick `
                -Name Test-NoFindingsRule `
                -Source Tests `
                -Callable {
                    [CmdletBinding()]
                    param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)
                }

            #=== Act ===#
            $Findings = $Rule.Invoke({}.Ast)

            #=== Assert ===#
            $Findings.Count | Should -Be 0
        }
    }

    It 'returns NitpickFinding objects when requested' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator

            $Context = @{
                RuleBehavior = @{ OutputType = 'NitpickFinding' }
            }

            #=== Act ===#
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
            }.Ast, $Context)

            #=== Assert ===#
            $Findings.Count | Should -Be 1
            $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        }
    }

    It 'returns DiagnosticRecord objects when requested' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator
            $Context = @{
                RuleBehavior = @{ OutputType = 'DiagnosticRecord' }
            }

            #=== Act ===#
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
            }.Ast, $Context)

            #=== Assert ===#
            $Findings.Count | Should -Be 1
            $Findings[0].GetType().Name | Should -Be 'DiagnosticRecord'
        }
    }

    It 'uses native output and nested traversal by default for both built-in rules' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Ast = {
                function Test-Value {
                    param([Parameter(Mandatory=$true)] [string] $Name)
                    -not ($Name -is [string])
                }
            }.Ast

            #=== Act & Assert ===#
            foreach ($Command in 'Test-UseIsNotOperator', 'Test-AvoidParameterAttributeBool') {
                $Rule = New-Nitpick -Callable $Command
                $Findings = $Rule.Invoke($Ast)

                $Findings | Should -HaveCount 1
                $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
            }
        }
    }

    It 'passes an ordered context dictionary only to an opted-in callable' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick -Name ContextRule -Source Tests -Callable {
                [CmdletBinding()]
                param(
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,
                    [System.Collections.IDictionary] $Context
                )
                $Context
            }
            $Context = [ordered]@{ Caller = 'TestHost'; Extra = 'preserved' }

            #=== Act ===#
            $Results = $Rule.Invoke({}.Ast, $Context)

            #=== Assert ===#
            $Results | Should -HaveCount 1
            [object]::ReferenceEquals($Results[0], $Context) | Should -BeFalse
            $Results[0].Caller | Should -BeExactly 'TestHost'
            $Results[0].Extra | Should -BeExactly 'preserved'
        }
    }

    It 'honors explicit scope-local traversal and native output for another caller' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Context = @{
                Caller = 'TestHost'
                RuleBehavior = @{
                    SearchNestedScriptBlocks = $false
                    OutputType = 'NitpickFinding'
                }
            }
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator

            #=== Act ===#
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
                & { -not ($Nested -is [string]) }
            }.Ast, $Context)

            #=== Assert ===#
            $Findings | Should -HaveCount 1
            $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        }
    }
}
