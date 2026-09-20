BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    $NitpickModulePath = Join-Path $PSScriptRoot '../../Nitpick.psd1'
}

Describe 'PSScriptAnalyzer integration' {
    It 'returns a Nitpick rule finding with a suggested correction' {
        $Results = @(Invoke-ScriptAnalyzer `
            -ScriptDefinition 'param([Parameter(Mandatory=$true)] [string] $Name)' `
            -CustomRulePath $NitpickModulePath `
            -IncludeRule Test-AvoidParameterAttributeBool)

        $Results.Count | Should -Be 1
        $Results[0].RuleName | Should -Be 'Test-AvoidParameterAttributeBool'
        $Results[0].Severity.ToString() | Should -Be 'Information'
        $Results[0].SuggestedCorrections.Count | Should -Be 1
    }
}
