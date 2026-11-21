using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    function Invoke-AvoidGlobalVarsRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty
        Test-AvoidGlobalVars -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{ SearchNestedScriptBlocks = $Recurse }
        }
    }
}

Describe 'Test-AvoidGlobalVars' {
    It 'reports global <Operation>' -ForEach @(
        @{ Operation = 'assignment'; Source = '$global:Result = 1'; Extent = '$global:Result' }
        @{ Operation = 'read'; Source = 'Write-Output $global:Result'; Extent = '$global:Result' }
        @{ Operation = 'string interpolation'; Source = '"Result: $global:Result"'; Extent = '$global:Result' }
        @{ Operation = 'member access'; Source = '$global:Result.Value'; Extent = '$global:Result' }
    ) {
        $Findings = @(Invoke-AvoidGlobalVarsRule -Source $Source)

        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/AvoidGlobalVars'
        $Findings[0].Severity | Should -Be 'Warning'
        $Findings[0].ViolationExtent.Text | Should -BeExactly $Extent
        $Findings[0].Message | Should -BeLike "*global:Result*"
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'ignores variables in other scopes' {
        $Source = @'
$LocalValue = 1
$local:ExplicitLocal = 2
$script:ModuleValue = 3
$env:FEATURE = 'enabled'
'@

        @(Invoke-AvoidGlobalVarsRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'respects nested scriptblock traversal' {
        $Source = 'function Set-Result { $global:Result = 1 }'

        @(Invoke-AvoidGlobalVarsRule -Source $Source) | Should -BeNullOrEmpty
        @(Invoke-AvoidGlobalVarsRule -Source $Source -Recurse $true) | Should -HaveCount 1
    }

    It 'supports metadata, discovery, coordination, and suppression' {
        $Details = Test-AvoidGlobalVars -Details
        $Details.Name | Should -Be 'AvoidGlobalVars'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Warning'
        @(Find-Nitpick -IncludeRule Nitpick/AvoidGlobalVars) | Should -HaveCount 1

        $Source = '$global:Result = 1 # nitpick disable-line Nitpick/AvoidGlobalVars -- Intentional shared state.'
        @(Start-Nitpicking -Script $Source -IncludeRule Nitpick/AvoidGlobalVars `
            -Output Object -NoSummary) | Should -BeNullOrEmpty
    }
}
