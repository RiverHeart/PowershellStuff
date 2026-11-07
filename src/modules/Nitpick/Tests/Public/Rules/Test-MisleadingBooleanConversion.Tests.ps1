using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force -ErrorAction Stop

    function Invoke-MisleadingBooleanConversionRule {
        param([string] $Source)

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty

        Test-MisleadingBooleanConversion -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{ OutputType = 'NitpickFinding' }
        }
    }
}

Describe 'Test-MisleadingBooleanConversion' {
    It 'reports nonempty string casts and Boolean parameter defaults' {
        $Source = @'
param([bool]$Enabled = 'false')
$WasParsedAsBoolean = [bool]'false'
$NonemptyIsStillTrue = [bool]'true'
$EmptyIsFalse = [bool]''
'@

        $Findings = @(Invoke-MisleadingBooleanConversionRule -Source $Source)

        $Findings | Should -HaveCount 3
        foreach ($Finding in $Findings) {
            $Finding.RuleId | Should -Be 'Nitpick/MisleadingBooleanConversion'
            $Finding.Message | Should -Be 'A nonempty string converts to $true, even when its text is false.'
        }
    }

    It 'does not report empty strings, non-Boolean casts, or parse calls' {
        $Source = @'
$Empty = [bool]''
$Text = [string]'false'
$Parsed = [bool]::Parse('false')
'@

        @(Invoke-MisleadingBooleanConversionRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'exposes rule metadata' {
        $Details = Test-MisleadingBooleanConversion -Details

        $Details.Name | Should -Be 'MisleadingBooleanConversion'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Warning'
    }
}
