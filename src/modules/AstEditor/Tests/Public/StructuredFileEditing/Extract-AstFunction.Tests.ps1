using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Extract-AstFunction' {
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
