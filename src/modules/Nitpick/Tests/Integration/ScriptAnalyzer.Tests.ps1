BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
}

Describe 'PSScriptAnalyzer integration' {
    It 'reports nested violations exactly once for both optional-context rules' {
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
        $Results = @(Invoke-ScriptAnalyzer -ScriptDefinition $Source `
            -CustomRulePath (Join-Path $PSScriptRoot '../../Nitpick.psd1') `
            -IncludeRule Test-AvoidParameterAttributeBool,Test-UseIsNotOperator -Settings @{})

        $Results | Should -HaveCount 4
        foreach ($RuleName in 'UseIsNotOperator', 'AvoidParameterAttributeBool') {
            $Findings = @($Results | Where-Object RuleName -eq $RuleName)
            $Findings | Should -HaveCount 2
            @($Findings | ForEach-Object { $_.Extent.StartOffset } | Sort-Object -Unique) |
                Should -HaveCount 2
            foreach ($Finding in $Findings) {
                $Finding.GetType().Name | Should -Be 'DiagnosticRecord'
            }
        }
    }

    It 'returns a Nitpick rule finding with a suggested correction' {
        # Pass an empty settings object to prevent PSScriptAnalyzer from
        # duplicating rules it finds using PSScriptAnalyzer.psd1
        $Settings = @{}
        $Results = @(Invoke-ScriptAnalyzer `
            -ScriptDefinition 'param([Parameter(Mandatory=$true)] [string] $Name)' `
            -CustomRulePath (Join-Path $PSScriptRoot '../../Nitpick.psd1') `
            -IncludeRule Test-AvoidParameterAttributeBool `
            -Settings $Settings
        )

        $Results.Count | Should -Be 1
        $Results[0].RuleName | Should -Be 'AvoidParameterAttributeBool'
        $Results[0].Severity.ToString() | Should -Be 'Information'
        $Results[0].SuggestedCorrections.Count | Should -Be 1
    }
}
