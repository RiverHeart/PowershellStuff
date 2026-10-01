using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../AstEditor.psd1" -Force

Describe 'AstEditor autocorrection contracts' -Tag 'AutocorrectionContract' {
    It 'treats edit ranges as zero-based and end-exclusive' {
        $Document = New-AstDocument -InputObject '0123456789'

        $Document.ReplaceRange(2, 5, 'ABC', 'Replace [2, 5)')
        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.RenderedText | Should -Be '01ABC56789'
    }

    It 'renders insertions, replacements, deletions, and adjacent ranges from one snapshot' {
        $Document = New-AstDocument -InputObject 'abcdefghij'

        $Document.Insert(0, '>', 'Insert at start')
        $Document.ReplaceRange(1, 3, 'BC', 'Replace [1, 3)')
        $Document.ReplaceRange(3, 5, '', 'Delete [3, 5)')
        $Document.ReplaceRange(5, 7, 'FGHIJ', 'Replace [5, 7) with longer text')

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.RenderedText | Should -Be '>aBCFGHIJhij'
    }

    It 'accepts ranges that meet at an end-exclusive boundary' {
        $Document = New-AstDocument -InputObject 'abcdef'

        $Document.ReplaceRange(1, 3, 'BC', 'Replace [1, 3)')
        { $Document.ReplaceRange(3, 5, 'DE', 'Replace [3, 5)') } |
            Should -Not -Throw
    }

    It 'rejects overlapping ranges from the same source snapshot' {
        $Document = New-AstDocument -InputObject 'abcdef'

        $Document.ReplaceRange(1, 4, 'first', 'First correction')

        { $Document.ReplaceRange(3, 5, 'second', 'Second correction') } |
            Should -Throw '*First correction*Second correction*offsets [[]3, 5)*'
    }

    It 'reports parse errors introduced by rendered edits' {
        $Document = New-AstDocument -InputObject '$Value = 1'
        $Document.ReplaceRange(9, 10, '(', 'Introduce an incomplete expression')

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.ParseErrorCount | Should -BeGreaterThan 0
        $Result.RenderedText | Should -Be '$Value = ('
    }

    It 'rejects multiple zero-width insertions at the same offset' -Skip {
        throw 'Phase 1 must define deterministic same-offset insertion rejection.'
    }

    It 'rejects an edit when expected source text does not match' -Skip {
        throw 'Phase 1 must expose expected-source validation through Add-AstTextEdit.'
    }

    It 'returns structured details for both edits in a conflict' -Skip {
        throw 'Phase 1 must replace raw overlap exceptions with structured conflict details.'
    }
}
