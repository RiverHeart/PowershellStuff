BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
}

Describe 'PSScriptAnalyzer integration' {
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
