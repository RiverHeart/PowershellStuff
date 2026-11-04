using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Extract-AstFunction' {
    It 'does not attach host help when the submitted fragment is a function AST' {
        $Help = "<#`r`n.SYNOPSIS`r`nHost help`r`n#>"
        $Text = "$Help`r`nfunction Get-Value { 1 }"
        $Root = [Parser]::ParseInput($Text, [ref] $null, [ref] $null)
        $Document = New-AstDocument -InputObject $Root.EndBlock.Statements[0]

        $Plan = Extract-AstFunction -Document $Document -Name Get-Value

        $Plan.IncludedHelp | Should -BeFalse
        $Plan.Text | Should -BeExactly 'function Get-Value { 1 }'
        $Document.Render() | Should -BeExactly "$Help`r`n"
    }

    It 'treats a function inside a fragment as top-level even when the host is a function' {
        $Text = 'function Get-Host { & { function Get-Value { 1 } } }'
        $Root = [Parser]::ParseInput($Text, [ref] $null, [ref] $null)
        $Fragment = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Document = New-AstDocument -InputObject $Fragment
        $Plan = Extract-AstFunction -Document $Document -Name Get-Value
        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.Text | Should -BeExactly 'function Get-Value { 1 }'
        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedText | Should -BeExactly 'function Get-Host { & {  } }'
        $Result.RenderedFragmentText | Should -BeExactly '{  }'
    }

    It 'extracts a top-level function with its adjacent help' {
        $Source = @'
<#
.SYNOPSIS
    Extracted help.
#>
function Get-Extracted {
    'extracted'
}

function Get-Remaining {
    'remaining'
}
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Extract-AstFunction -Document $Document -Name Get-Extracted
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeTrue
        $Plan.Text | Should -Match 'Extracted help\.'
        $Plan.Text | Should -Match 'function Get-Extracted'
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.RenderedText | Should -Not -Match 'Get-Extracted'
        $Validation.RenderedText | Should -Match 'Get-Remaining'
    }

    It 'does not treat class constructors or methods as top-level functions' {
        $Source = @'
class Example {
    Example() {}
    [void] Invoke() {}
}

function Get-Remaining { 'remaining' }
'@
        $Document = New-AstDocument -InputObject $Source

        {
            Extract-AstFunction -Document $Document -Name Example
        } | Should -Throw "Function 'Example' was not found in the top level of the document."

        $Document.Edits.Count | Should -Be 0
    }
}
