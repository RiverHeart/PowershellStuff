using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Parses a fixture and invokes the type-resolution rule.
    #>
    function Invoke-TypeResolutionRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty
        Test-PossibleTypeResolutionFailure -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-PossibleTypeResolutionFailure' {
    It 'reports <Label>' -ForEach @(
        @{
            Label = 'assigned ToString serialization'
            Source = @'
using namespace System.Collections
$Block = { param([IDictionary] $Values) }
$PowerShell.AddScript($Block.ToString())
'@
            TypeText = '[IDictionary]'
        }
        @{
            Label = 'inline ToString serialization'
            Source = @'
using namespace System.Collections.Generic
({ [HashSet[string]]::new() }).ToString()
'@
            TypeText = '[HashSet[string]]'
        }
        @{
            Label = 'direct AddScript scriptblock coercion'
            Source = @'
using namespace System.Collections
$Block = { $Map -is [IDictionary] }
$PowerShell.AddScript($Block)
'@
            TypeText = '[IDictionary]'
        }
        @{
            Label = 'direct ScriptBlock.Create coercion'
            Source = @'
using namespace System.Collections
$Block = { param([IDictionary] $Values) }
[scriptblock]::Create($Block)
'@
            TypeText = '[IDictionary]'
        }
        @{
            Label = 'a constant AddScript string'
            Source = @'
using namespace System.Collections
$PowerShell.AddScript('param([IDictionary] $Values)')
'@
            TypeText = $null
        }
        @{
            Label = 'a constant ScriptBlock.Create string'
            Source = @'
using namespace System.Collections.Generic
[scriptblock]::Create('param([List[string]] $Values)')
'@
            TypeText = $null
        }
        @{
            Label = 'a namespace-dependent type in dynamicparam'
            Source = @'
using namespace System.Management.Automation
function Invoke-Example {
    [CmdletBinding()]
    param()
    dynamicparam {
        $Parameters = [RuntimeDefinedParameterDictionary]::new()
        $Parameters
    }
}
'@
            TypeText = '[RuntimeDefinedParameterDictionary]'
        }
        @{
            Label = 'short OutputType metadata on a dynamicparam helper'
            Source = @'
using namespace System.Management.Automation
function Resolve-Parameters {
    [OutputType([RuntimeDefinedParameterDictionary])]
    param()
}
function Invoke-Example {
    [CmdletBinding()]
    param()
    dynamicparam { Resolve-Parameters }
}
'@
            TypeText = '[RuntimeDefinedParameterDictionary]'
        }
    ) {
        $Findings = @(Invoke-TypeResolutionRule -Source $Source)

        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/PossibleTypeResolutionFailure'
        $Findings[0].Severity | Should -Be 'Warning'
        $Findings[0].Corrections | Should -BeNullOrEmpty
        if ($TypeText) {
            $Findings[0].ViolationExtent.Text | Should -Be $TypeText
        } else {
            $Findings[0].ViolationExtent.Text | Should -BeLike "'*'"
        }
    }

    It 'reports each namespace-dependent type reference once' {
        $Source = @'
using namespace System.Collections
$Block = {
    param([IDictionary] $Values)
    $Values -is [IList]
}
$PowerShell.AddScript($Block.ToString())
'@

        $Findings = @(Invoke-TypeResolutionRule -Source $Source)
        $Findings | Should -HaveCount 2
        $Findings.ViolationExtent.Text | Should -Be @('[IDictionary]', '[IList]')
    }

    It 'does not report <Label>' -ForEach @(
        @{
            Label = 'fully qualified types'
            Source = @'
using namespace System.Collections
$Block = { param([System.Collections.IDictionary] $Values) }
$PowerShell.AddScript($Block.ToString())
'@
        }
        @{
            Label = 'built-in type accelerators'
            Source = @'
using namespace System.Collections
$Block = { param([string] $Value) }
$PowerShell.AddScript($Block.ToString())
'@
        }
        @{
            Label = 'type accelerators within fully qualified generic types'
            Source = @'
using namespace System.Collections
$Block = {
    param([System.Collections.Generic.List[hashtable]] $Values)
    [pscustomobject] @{}
}
$PowerShell.AddScript($Block.ToString())
'@
        }
        @{
            Label = 'a fully qualified dynamicparam type'
            Source = @'
using namespace System.Management.Automation
function Invoke-Example {
    [CmdletBinding()]
    param()
    dynamicparam {
        [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    }
}
'@
        }
        @{
            Label = 'short OutputType metadata outside dynamicparam'
            Source = @'
using namespace System.Management.Automation
function Resolve-Parameters {
    [OutputType([RuntimeDefinedParameterDictionary])]
    param()
}
Resolve-Parameters
'@
        }
        @{
            Label = 'an ordinary deferred invocation'
            Source = @'
using namespace System.Collections
$Block = { param([IDictionary] $Values) }
& $Block @{}
'@
        }
        @{
            Label = 'a short type without a matching using statement'
            Source = @'
$Block = { param([IDictionary] $Values) }
$PowerShell.AddScript($Block.ToString())
'@
        }
        @{
            Label = 'a dynamically constructed string'
            Source = @'
using namespace System.Collections
$Type = 'IDictionary'
$PowerShell.AddScript("param([$Type] `$Values)")
'@
        }
        @{
            Label = 'an unknown variable source'
            Source = @'
using namespace System.Collections
$PowerShell.AddScript($Block)
'@
        }
        @{
            Label = 'an unrelated Create method'
            Source = @'
using namespace System.Collections
$Block = { param([IDictionary] $Values) }
[Factory]::Create($Block)
'@
        }
    ) {
        @(Invoke-TypeResolutionRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'requires nested traversal for function-local serialization' {
        $Source = @'
using namespace System.Collections
function Invoke-Example {
    $Block = { param([IDictionary] $Values) }
    $PowerShell.AddScript($Block.ToString())
}
'@

        @(Invoke-TypeResolutionRule -Source $Source) | Should -BeNullOrEmpty
        @(Invoke-TypeResolutionRule -Source $Source -Recurse $true) | Should -HaveCount 1
    }

    It 'provides metadata and coordinated identity' {
        $Details = Test-PossibleTypeResolutionFailure -Details
        $Details.Name | Should -Be 'PossibleTypeResolutionFailure'
        $Details.Category | Should -Be 'Correctness'
        $Details.Severity | Should -Be 'Warning'

        @(Find-Nitpick -IncludeRule Nitpick/PossibleTypeResolutionFailure) |
            Should -HaveCount 1

        $Source = @'
using namespace System.Collections
$Block = { param([IDictionary] $Values) }
$PowerShell.AddScript($Block.ToString())
'@
        $Findings = @(Start-Nitpicking -Script $Source `
            -IncludeRule Nitpick/PossibleTypeResolutionFailure `
            -Output Object -NoSummary)
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/PossibleTypeResolutionFailure'
    }

    It 'supports native suppression' {
        $Source = @'
using namespace System.Collections
$Block = { param([IDictionary] $Values) } # nitpick disable-line Nitpick/PossibleTypeResolutionFailure -- Reparse imports the namespace.
$PowerShell.AddScript($Block.ToString())
'@

        @(Start-Nitpicking -Script $Source `
            -IncludeRule Nitpick/PossibleTypeResolutionFailure `
            -Output Object -NoSummary) | Should -BeNullOrEmpty
    }
}
