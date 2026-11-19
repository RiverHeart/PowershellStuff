BeforeAll {
    $AdapterManifest = Join-Path $PSScriptRoot '..\Nitpick.ScriptAnalyzer.psd1'
    Import-Module $AdapterManifest -Force -ErrorAction Stop
}

Describe 'Nitpick.ScriptAnalyzer adapter discovery' {
    It 'exports one wrapper for every built-in Nitpick rule' {
        $Rules = @(Find-Nitpick -ErrorAction Stop)
        $ExpectedNames = @($Rules | ForEach-Object { "Test-$($_.Name)" })
        $ActualNames = @(
            Get-Command -Module Nitpick.ScriptAnalyzer |
                Select-Object -ExpandProperty Name
        )

        $ActualNames | Should -HaveCount $ExpectedNames.Count
        foreach ($ExpectedName in $ExpectedNames) {
            $ActualNames | Should -Contain $ExpectedName
        }
    }

    It 'discovers generated commands through PSScriptAnalyzer' {
        $AdapterRules = @(Get-ScriptAnalyzerRule -CustomRulePath $AdapterManifest)
        $ExpectedCount = @(Find-Nitpick -ErrorAction Stop).Count

        $AdapterRules | Should -HaveCount $ExpectedCount
        $AdapterRules.SourceName | Should -Contain 'Nitpick.ScriptAnalyzer'

        $UseIsNotRule = $AdapterRules |
            Where-Object RuleName -eq 'Test-UseIsNotOperator'
        $UseIsNotRule.Description | Should -Match '-isnot'
    }

    It 'returns generated metadata without an AST' {
        $Details = Test-UseIsNotOperator -Details

        $Details.Name | Should -BeExactly 'UseIsNotOperator'
        $Details.Category | Should -BeExactly 'Style'
        $Details.Severity | Should -BeExactly 'Information'
    }
}

Describe 'Nitpick.ScriptAnalyzer rule invocation' {
    It 'converts a native finding to a DiagnosticRecord' {
        $Diagnostic = @(
            Invoke-ScriptAnalyzer `
                -ScriptDefinition '$Value = -not ($Other -is [string])' `
                -CustomRulePath $AdapterManifest `
                -IncludeRule Test-UseIsNotOperator `
                -Settings @{}
        )

        $Diagnostic | Should -HaveCount 1
        $Diagnostic[0].GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
        $Diagnostic[0].RuleName | Should -BeExactly 'UseIsNotOperator'
        $Diagnostic[0].RuleSuppressionID | Should -BeExactly 'UseIsNotOperator'
        $Diagnostic[0].Severity.ToString() | Should -BeExactly 'Information'
    }

    It 'reports each nested scriptblock scope exactly once' {
        $Source = @'
function Test-Outer {
    param([Parameter(Mandatory=$true)] [string] $Name)
    -not ($Name -is [string])
    & {
        param([Parameter(Mandatory=$true)] [string] $Nested)
        -not ($Nested -is [string])
    }
}
'@
        $Diagnostics = @(
            Invoke-ScriptAnalyzer `
                -ScriptDefinition $Source `
                -CustomRulePath $AdapterManifest `
                -IncludeRule Test-AvoidParameterAttributeBool,Test-UseIsNotOperator `
                -Settings @{}
        )

        $Diagnostics | Should -HaveCount 4
        foreach ($RuleName in 'UseIsNotOperator', 'AvoidParameterAttributeBool') {
            $Findings = @($Diagnostics | Where-Object RuleName -eq $RuleName)
            $Findings | Should -HaveCount 2
            @($Findings.Extent.StartOffset | Sort-Object -Unique) | Should -HaveCount 2
        }
    }

    It 'passes explicit rule settings through direct wrapper invocation' {
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
            ('x' * 10),
            [ref] $null,
            [ref] $null
        )

        $Diagnostics = @(
            Test-AvoidLongLines -ScriptBlockAst $Ast -Options @{ MaximumLength = 5 }
        )

        $Diagnostics | Should -HaveCount 1
        $Diagnostics[0].Message | Should -BeExactly 'Line has 10 UTF-16 code units; maximum is 5.'
    }

    It 'exports a single-edit correction as a suggested correction' {
        $Diagnostics = @(
            Invoke-ScriptAnalyzer `
                -ScriptDefinition 'param([Parameter(Mandatory=$true)] [string] $Name)' `
                -CustomRulePath $AdapterManifest `
                -IncludeRule Test-AvoidParameterAttributeBool `
                -Settings @{}
        )

        $Diagnostics | Should -HaveCount 1
        $Diagnostics[0].SuggestedCorrections | Should -HaveCount 1
        $Diagnostics[0].SuggestedCorrections[0].Text | Should -BeExactly ''
    }

    It 'omits a multi-edit correction instead of splitting the atomic fix' {
        $Diagnostics = @(
            Invoke-ScriptAnalyzer `
                -ScriptDefinition '-not (''literal -is'' -is [string])' `
                -CustomRulePath $AdapterManifest `
                -IncludeRule Test-UseIsNotOperator `
                -Settings @{}
        )

        $Diagnostics | Should -HaveCount 1
        $Diagnostics[0].SuggestedCorrections | Should -BeNullOrEmpty
    }
}
