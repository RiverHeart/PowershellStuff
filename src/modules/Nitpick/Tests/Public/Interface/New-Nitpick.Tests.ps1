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

                [Parameter(ParameterSetName='Details')]
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
