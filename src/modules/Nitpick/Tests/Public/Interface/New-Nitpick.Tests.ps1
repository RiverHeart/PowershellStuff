BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force

    function Test-NitpickRule {
        [CmdletBinding()]
        param (
            [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst
        )
    }

    function BareNitpickRule {
        [CmdletBinding()]
        param (
            [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst
        )
    }
}

AfterAll {
    Remove-Item -Path Function:\Test-NitpickRule -ErrorAction SilentlyContinue
    Remove-Item -Path Function:\BareNitpickRule -ErrorAction SilentlyContinue
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-Nitpick' {
    It 'retains optional execution declarations without evaluating them at construction' {
        $Predicate = { throw 'must not run during construction' }
        $Rule = New-Nitpick -Name Declared -Source Tests -Callable {
            param($ScriptBlockAst)
        } -Applicability $Predicate -MinimumAnalysisHostVersion ([version] '999.0')

        [object]::ReferenceEquals($Rule.Applicability, $Predicate) | Should -BeTrue
        $Rule.MinimumAnalysisHostVersion | Should -Be ([version] '999.0')
    }

    It 'preserves Details declarations and supports explicit null clears' {
        $Producer = {
            [CmdletBinding(DefaultParameterSetName='Rule')]
            param(
                [Parameter(Mandatory,ParameterSetName='Rule')]
                $ScriptBlockAst,

                [Parameter(Mandatory,ParameterSetName='Details')]
                [switch] $Details
            )
            if ($Details) {
                return @{
                    Applicability = { $false }
                    MinimumAnalysisHostVersion = [version] '999.0'
                }
            }
        }
        $Rule = New-Nitpick -Callable $Producer -Name Declared -Source Tests
        $Rule.Applicability | Should -BeOfType ([scriptblock])
        $Rule.MinimumAnalysisHostVersion | Should -Be ([version] '999.0')
        $Rule.InvokeWithResult({}.Ast, @{}).Status | Should -BeExactly 'Inapplicable'

        $Cleared = New-Nitpick -Callable $Producer -Name Declared -Source Tests `
            -Applicability $null -MinimumAnalysisHostVersion $null
        $Cleared.Applicability | Should -BeNullOrEmpty
        $Cleared.MinimumAnalysisHostVersion | Should -BeNullOrEmpty
        $Cleared.InvokeWithResult({}.Ast, @{}).Status | Should -BeExactly 'Executed'

        $Override = { $true }
        $Changed = New-Nitpick -Callable $Producer -Name Declared -Source Tests `
            -Applicability $Override -MinimumAnalysisHostVersion ([version] '5.1')
        [object]::ReferenceEquals($Changed.Applicability, $Override) | Should -BeTrue
        $Changed.MinimumAnalysisHostVersion | Should -Be ([version] '5.1')
    }

    It 'rejects malformed <Property> metadata before implicit conversion' -ForEach @(
        @{ Property = 'Applicability'; Value = '$true' }
        @{ Property = 'Applicability'; Value = $false }
        @{ Property = 'Applicability'; Value = @{} }
        @{ Property = 'MinimumAnalysisHostVersion'; Value = '7.0' }
        @{ Property = 'MinimumAnalysisHostVersion'; Value = 7 }
        @{ Property = 'MinimumAnalysisHostVersion'; Value = [version] '0.1' }
        @{ Property = 'MinimumAnalysisHostVersion'; Value = [version] '7.0.0' }
        @{ Property = 'MinimumAnalysisHostVersion'; Value = [version] '7.0.0.0' }
    ) {
        $Overrides = @{ $Property = $Value }
        {
            New-Nitpick -Name Malformed -Source Tests -Callable { param($ScriptBlockAst) } @Overrides
        } | Should -Throw "*$Property*"

        $Producer = {
            [CmdletBinding(DefaultParameterSetName='Rule')]
            param(
                [Parameter(Mandatory,ParameterSetName='Rule')]
                $ScriptBlockAst,

                [Parameter(Mandatory,ParameterSetName='Details')]
                [switch] $Details
            )
            if ($Details) { return @{ $Property = $Value } }
        }.GetNewClosure()
        { New-Nitpick -Callable $Producer -Name MalformedDetails -Source Tests } |
            Should -Throw "*$Property*"
    }

    It 'creates a rule from a scriptblock' {
        $Rule = New-Nitpick -Callable {
            param (
                [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst
            )
        } -Category Style -Name TestRule -Source Tests

        $Rule.GetType().Name | Should -Be 'NitpickRule'
        $Rule.Name | Should -Be 'TestRule'
        $Rule.Category | Should -Be 'Style'
        $Rule.CallableType | Should -Be 'ScriptBlock'
        $Rule.Callable | Should -BeOfType [scriptblock]
        $Rule.Source | Should -Be 'Tests'
        $Rule.EditorEnabled | Should -BeTrue
    }

    It 'creates a rule from a function info object' {
        $Rule = New-Nitpick `
            -Callable (Get-Command -Name Test-UseIsNotOperator -CommandType Function) `
            -Category Quality

        $Rule.Name | Should -Be 'UseIsNotOperator'
        $Rule.Category | Should -Be 'Quality'
        $Rule.CallableType | Should -Be 'Function'
        $Rule.Callable | Should -Be 'Test-UseIsNotOperator'
        $Rule.Source | Should -Be 'Nitpick'
    }

    It 'uses the full command name when no noun is available' {
        $Rule = New-Nitpick `
            -Callable (Get-Command -Name BareNitpickRule -CommandType Function) `
            -Source Tests

        $Rule.Name | Should -Be 'BareNitpickRule'
    }

    It 'creates a rule from a command name' {
        $Rule = New-Nitpick -Callable 'Test-UseIsNotOperator' -Category Maintainability

        $Rule.Name | Should -Be 'UseIsNotOperator'
        $Rule.Category | Should -Be 'Maintainability'
        $Rule.Callable | Should -Be 'Test-UseIsNotOperator'
        $Rule.Source | Should -Be 'Nitpick'
    }

    It 'uses rule details when no explicit override is supplied' {
        $Rule = New-Nitpick -Callable 'Test-UseIsNotOperator'

        $Rule.Name | Should -Be 'UseIsNotOperator'
        $Rule.Category | Should -Be 'Style'
        $Rule.Description | Should -Not -BeNullOrEmpty
        $Rule.Severity | Should -Be 'Information'
        $Rule.Explanation | Should -Not -BeNullOrEmpty
    }

    It 'uses path scopes from rule details' {
        $RuleScript = {
            [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
            param (
                [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
                [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,

                [Parameter(Mandatory,ParameterSetName='Details')]
                [switch] $Details
            )

            if ($Details) {
                [pscustomobject]@{
                    IncludePath = @('*.dsl.ps1')
                    ExcludePath = @('*/Tests/*')
                }
            }
        }

        $Rule = New-Nitpick `
            -Callable $RuleScript `
            -Name ScopedNitpickRule `
            -Source Tests

        $Rule.IncludePath | Should -Be @('*.dsl.ps1')
        $Rule.ExcludePath | Should -Be @('*/Tests/*')
    }

    It 'uses editor availability from rule details' {
        $RuleScript = {
            [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
            param (
                [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
                [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,

                [Parameter(Mandatory,ParameterSetName='Details')]
                [switch] $Details
            )

            if ($Details) {
                [pscustomobject]@{
                    EditorEnabled = $false
                }
            }
        }

        $Rule = New-Nitpick `
            -Callable $RuleScript `
            -Name SlowNitpickRule `
            -Source Tests

        $Rule.EditorEnabled | Should -BeFalse
    }

    It 'allows editor availability to be explicitly overridden' {
        $Rule = New-Nitpick `
            -Callable {
                param (
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst
                )
            } `
            -Name SlowNitpickRule `
            -Source Tests `
            -EditorEnabled:$false

        $Rule.EditorEnabled | Should -BeFalse
    }

    It 'rejects a callable missing ScriptBlockAst' {
        {
            New-Nitpick -Callable { param ($FilePath) } -Category Style -Name BadRule -Source Tests -ErrorAction Stop
        } | Should -Throw '*ScriptBlockAst*'
    }

    It 'rejects an unknown command name' {
        {
            New-Nitpick -Callable 'NoSuchNitpickRule' -Category Style -ErrorAction Stop
        } | Should -Throw
    }

    It 'requires name and source for a scriptblock' {
        {
            New-Nitpick -Callable { param ($ScriptBlockAst) } -Category Style -ErrorAction Stop
        } | Should -Throw '*Name and Source*'
    }

    It 'requires source for a non-module function' {
        {
            New-Nitpick `
                -Callable (Get-Command -Name Test-NitpickRule -CommandType Function) `
                -Category Style `
                -ErrorAction Stop
        } | Should -Throw '*Source*'
    }
}
