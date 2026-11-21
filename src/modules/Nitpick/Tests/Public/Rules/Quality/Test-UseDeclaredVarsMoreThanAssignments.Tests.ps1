using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    function Invoke-DeclaredVariableRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty
        Test-UseDeclaredVarsMoreThanAssignments -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{ SearchNestedScriptBlocks = $Recurse }
        }
    }
}

Describe 'Test-UseDeclaredVarsMoreThanAssignments' {
    It 'reports a variable assigned but never read' {
        $Findings = @(Invoke-DeclaredVariableRule -Source '$Unused = 1')

        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/UseDeclaredVarsMoreThanAssignments'
        $Findings[0].Severity | Should -Be 'Warning'
        $Findings[0].ViolationExtent.Text | Should -Be '$Unused'
        $Findings[0].Message | Should -Be "Variable 'Unused' is assigned but never used."
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'does not report a read, including a read in a nested scriptblock' -ForEach @(
        @{ Label = 'same scope'; Source = '$Used = 1; Write-Output $Used' }
        @{ Label = 'right side'; Source = '$Used = $Used' }
        @{ Label = 'compound assignment'; Source = '$Used = 1; $Used += 2' }
        @{ Label = 'increment'; Source = '$Used = 1; $Used++' }
        @{ Label = 'nested scriptblock'; Source = '$Used = 1; & { Write-Output $Used }' }
        @{ Label = 'function body'; Source = '$Used = 1; function Get-Used { $Used }' }
    ) {
        @(Invoke-DeclaredVariableRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'excludes parameters, automatic variables, and externally shared scopes' {
        $Source = @'
param($DeclaredParameter)
$DeclaredParameter = 2
$_ = 1
$PSScriptRoot = 'changed'
$global:Shared = 1
$script:ModuleState = 2
$env:Feature = 'enabled'
'@

        @(Invoke-DeclaredVariableRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'reports each unread assignment in its own lexical scope' {
        $Source = @'
$Outer = 1
function Test-Outer {
    $Inner = 2
}
'@

        $TopLevel = @(Invoke-DeclaredVariableRule -Source $Source)
        $Recursive = @(Invoke-DeclaredVariableRule -Source $Source -Recurse $true)

        $TopLevel | Should -HaveCount 1
        $TopLevel.ViolationExtent.Text | Should -Be '$Outer'
        $Recursive | Should -HaveCount 2
        $Recursive.ViolationExtent.Text | Should -Be @('$Outer', '$Inner')
    }

    It 'reports repeated unread assignments only at the first assignment' {
        $Findings = @(Invoke-DeclaredVariableRule -Source '$Unused = 1; $Unused = 2')

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.StartOffset | Should -Be 0
    }

    It 'does not let an outer read count as use of an inner assignment' {
        $Source = 'function Get-Inner { $Inner = 2 }; Write-Output $Inner'

        $Findings = @(Invoke-DeclaredVariableRule -Source $Source -Recurse $true)

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.Text | Should -Be '$Inner'
    }

    It 'supports metadata, discovery, coordinated identity, and suppression' {
        $Details = Test-UseDeclaredVarsMoreThanAssignments -Details
        $Details.Name | Should -Be 'UseDeclaredVarsMoreThanAssignments'
        $Details.Category | Should -Be 'Quality'
        $Details.Severity | Should -Be 'Warning'
        @(Find-Nitpick -IncludeRule Nitpick/UseDeclaredVarsMoreThanAssignments) |
            Should -HaveCount 1

        $Source = '$Unused = 1 # nitpick disable-line Nitpick/UseDeclaredVarsMoreThanAssignments -- Reserved for a future step.'
        @(Start-Nitpicking -Script $Source `
            -IncludeRule Nitpick/UseDeclaredVarsMoreThanAssignments `
            -Output Object -NoSummary) | Should -BeNullOrEmpty
    }
}
