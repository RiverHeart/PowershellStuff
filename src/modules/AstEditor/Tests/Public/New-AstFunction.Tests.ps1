using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Set-AstFunction' {
    It 'replaces a function inside the fragment without selecting a host function of the same name' {
        $Text = 'function Get-Value { 0 }; function Get-Host { & { function Get-Value { 1 } } }'
        $Root = [Parser]::ParseInput($Text, [ref] $null, [ref] $null)
        $Fragment = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Document = New-AstDocument -InputObject $Fragment
        $Plan = Set-AstFunction -Document $Document -Name Get-Value -Replacement 'function Get-Value { 22 }'
        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.Name | Should -Be 'Get-Value'
        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedFragmentText | Should -BeExactly '{ function Get-Value { 22 } }'
        $Result.RenderedText | Should -BeExactly (
            'function Get-Value { 0 }; function Get-Host { & { function Get-Value { 22 } } }'
        )
    }

    It 'does not replace host help outside a function fragment' {
        $Help = "<#`r`n.SYNOPSIS`r`nHost help`r`n#>"
        $Text = "$Help`r`nfunction Get-Value { 1 }"
        $Root = [Parser]::ParseInput($Text, [ref] $null, [ref] $null)
        $Document = New-AstDocument -InputObject $Root.EndBlock.Statements[0]

        $Plan = Set-AstFunction -Document $Document -Name Get-Value -Replacement 'function Get-Value { 2 }'
        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeFalse
        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedText | Should -BeExactly "$Help`r`nfunction Get-Value { 2 }"
    }

    It 'replaces one top-level function and its adjacent help' {
        $Source = @'
<#
.SYNOPSIS
    Old help.
#>
function Get-Greeting {
    'old'
}

function Get-Unchanged {
    'unchanged'
}
'@
        $Replacement = @'
<#
.SYNOPSIS
    New help.
#>
function Get-Greeting {
    'new'
}
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Get-Greeting `
            -Replacement $Replacement
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeTrue
        $Plan.Name | Should -Be 'Get-Greeting'
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match 'New help\.'
        $Validation.RenderedText | Should -Not -Match 'Old help\.'
        $Validation.RenderedText | Should -Match 'Get-Unchanged'
    }

    It 'preserves adjacent help when ExcludeHelp is specified' {
        $Source = @'
<#
.SYNOPSIS
    Preserved help.
#>
function Get-Greeting {
    'old'
}
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }" `
            -ExcludeHelp
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeFalse
        $Validation.RenderedText | Should -Match 'Preserved help\.'
        $Validation.RenderedText | Should -Match "'new'"
    }

    It 'selects a top-level function without matching a nested function of the same name' {
        $Source = @'
function Invoke-Outer {
    function Invoke-Target { 'nested' }
    Invoke-Target
}

function Invoke-Target { 'top-level' }
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Invoke-Target `
            -Replacement "function Invoke-Target { 'replaced' }"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.TargetAst.Extent.StartLineNumber | Should -Be 6
        $Validation.RenderedText | Should -Match "Invoke-Target \{ 'nested' \}"
        $Validation.RenderedText | Should -Match "Invoke-Target \{ 'replaced' \}"
    }

    It 'requires Recurse to select a nested function' {
        $Source = @'
function Invoke-Outer {
    function Invoke-Target { 'nested' }
}
'@
        $Document = New-AstDocument -InputObject $Source

        {
            Set-AstFunction `
                -Document $Document `
                -Name Invoke-Target `
                -Replacement "function Invoke-Target { 'new' }"
        } | Should -Throw "Function 'Invoke-Target' was not found in the top level of the document."

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Invoke-Target `
            -Replacement "function Invoke-Target { 'new' }" `
            -Recurse

        $Plan.TargetAst.Extent.StartLineNumber | Should -Be 2
    }

    It 'rejects ambiguous recursive matches with source locations' {
        $Source = @'
function Invoke-First {
    function Invoke-Target { 'first' }
}
function Invoke-Second {
    function Invoke-Target { 'second' }
}
'@
        $Document = New-AstDocument -InputObject $Source

        {
            Set-AstFunction `
                -Document $Document `
                -Name Invoke-Target `
                -Replacement "function Invoke-Target { 'new' }" `
                -Recurse
        } | Should -Throw "Function 'Invoke-Target' is ambiguous. Matches were found at 2:5, 5:5."
    }

    It 'rejects replacement text that is not exactly one function definition' {
        $Document = New-AstDocument -InputObject "function Get-Greeting { 'old' }"

        {
            Set-AstFunction `
                -Document $Document `
                -Name Get-Greeting `
                -Replacement "function Get-One {}; function Get-Two {}"
        } | Should -Throw 'Replacement must contain exactly one complete function definition.'

        $Document.Edits.Count | Should -Be 0
    }

    It 'rejects malformed replacement text before queuing an edit' {
        $Document = New-AstDocument -InputObject "function Get-Greeting { 'old' }"

        {
            Set-AstFunction `
                -Document $Document `
                -Name Get-Greeting `
                -Replacement 'function Get-Greeting {'
        } | Should -Throw 'Replacement text contains * parse error(s): *'

        $Document.Edits.Count | Should -Be 0
    }
}
