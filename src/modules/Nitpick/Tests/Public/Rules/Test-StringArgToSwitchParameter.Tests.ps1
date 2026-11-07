using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force -ErrorAction Stop

    function Invoke-StringArgToSwitchParameterRule {
        param([string] $Source)

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty

        Test-StringArgToSwitchParameter -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{ OutputType = 'NitpickFinding' }
        }
    }

}

Describe 'Test-StringArgToSwitchParameter' {
    It 'reports false-like strings after locally declared switch parameters' {
        $Source = @'
function Invoke-Example { param([switch]$Force) }
Invoke-Example -Force 'false'
'@

        $Findings = @(Invoke-StringArgToSwitchParameterRule -Source $Source)

        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/StringArgToSwitchParameter'
        $Findings[0].ViolationExtent.Text | Should -Be "'false'"
        $Findings[0].Message | Should -BeLike '*separate argument*'
    }

    It 'uses current command metadata when available' {
        $Findings = @(Invoke-StringArgToSwitchParameterRule -Source "Get-Item -Force 'false'")

        $Findings | Should -HaveCount 1
        $Findings[0].Message | Should -BeLike '*-Force switch*'
    }

    It 'does not report explicit switch values, ordinary strings, or unknown metadata' {
        $Source = @'
function Invoke-Example { param([switch]$Force) }
Invoke-Example -Force:$false
Invoke-Example -Force 'enabled'
Unknown-Example -Force 'false'
'@

        @(Invoke-StringArgToSwitchParameterRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'exposes rule metadata' {
        $Details = Test-StringArgToSwitchParameter -Details

        $Details.Name | Should -Be 'StringArgToSwitchParameter'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Information'
    }
}
