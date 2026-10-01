using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../AstEditor.psd1" -Force

Describe 'AstEditor autocorrection contracts' -Tag 'AutocorrectionContract' {
    It 'treats edit ranges as zero-based and end-exclusive' {
        $Document = New-AstDocument -InputObject '0123456789'

        $null = Add-AstTextEdit `
            -Document $Document `
            -StartOffset 2 `
            -EndOffset 5 `
            -ReplacementText 'ABC' `
            -Reason 'Replace [2, 5)'
        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.RenderedText | Should -Be '01ABC56789'
    }

    It 'renders insertions, replacements, deletions, and adjacent ranges from one snapshot' {
        $Document = New-AstDocument -InputObject 'abcdefghij'

        $null = Add-AstTextEdit -Document $Document -StartOffset 0 -EndOffset 0 -ReplacementText '>' -Reason 'Insert at start'
        $null = Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 3 -ReplacementText 'BC' -Reason 'Replace [1, 3)'
        $null = Add-AstTextEdit -Document $Document -StartOffset 3 -EndOffset 5 -ReplacementText '' -Reason 'Delete [3, 5)'
        $null = Add-AstTextEdit -Document $Document -StartOffset 5 -EndOffset 7 -ReplacementText 'FGHIJ' -Reason 'Replace [5, 7) with longer text'

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.RenderedText | Should -Be '>aBCFGHIJhij'
    }

    It 'accepts ranges that meet at an end-exclusive boundary' {
        $Document = New-AstDocument -InputObject 'abcdef'

        $null = Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 3 -ReplacementText 'BC' -Reason 'Replace [1, 3)'
        { Add-AstTextEdit -Document $Document -StartOffset 3 -EndOffset 5 -ReplacementText 'DE' -Reason 'Replace [3, 5)' } |
            Should -Not -Throw
    }

    It 'rejects overlapping ranges from the same source snapshot' {
        $Document = New-AstDocument -InputObject 'abcdef'

        $null = Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 4 -ReplacementText 'first' -Reason 'First correction'

        { Add-AstTextEdit -Document $Document -StartOffset 3 -EndOffset 5 -ReplacementText 'second' -Reason 'Second correction' } |
            Should -Throw '*First correction*Second correction*offsets [[]3, 5)*'
    }

    It 'reports parse errors introduced by rendered edits' {
        $Document = New-AstDocument -InputObject '$Value = 1'
        $null = Add-AstTextEdit -Document $Document -StartOffset 9 -EndOffset 10 -ReplacementText '(' -Reason 'Introduce an incomplete expression'

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.ParseErrorCount | Should -BeGreaterThan 0
        $Result.RenderedText | Should -Be '$Value = ('
    }

    It 'queues edits by script extent and returns structured details' {
        $Document = New-AstDocument -InputObject '$Value = 1'
        $Extent = $Document.Ast.EndBlock.Statements[0].Left.Extent

        $Queued = Add-AstTextEdit `
            -Document $Document `
            -Extent $Extent `
            -ReplacementText '$Result' `
            -Reason 'Rename the variable' `
            -ExpectedText '$Value'

        $Queued.PSTypeNames | Should -Contain 'AstEditor.TextEditResult'
        $Queued.Status | Should -Be 'Queued'
        $Queued.StartOffset | Should -Be $Extent.StartOffset
        $Queued.EndOffset | Should -Be $Extent.EndOffset
        $Document.Edits.Count | Should -Be 1
    }

    It 'rejects an out-of-range edit' {
        $Document = New-AstDocument -InputObject 'abc'

        {
            Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 4 -ReplacementText 'x' -Reason 'Out of range'
        } | Should -Throw '*EndOffset 4 exceeds document length 3*'

        $Document.Edits.Count | Should -Be 0
    }

    It 'rejects multiple zero-width insertions at the same offset' {
        $Document = New-AstDocument -InputObject 'abc'
        $null = Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 1 -ReplacementText 'first' -Reason 'First insertion'

        {
            Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 1 -ReplacementText 'second' -Reason 'Second insertion'
        } | Should -Throw '*First insertion*Second insertion*'

        $Document.Edits.Count | Should -Be 1
    }

    It 'rejects an edit when expected source text does not match' {
        $Document = New-AstDocument -InputObject 'abc'

        {
            Add-AstTextEdit `
                -Document $Document `
                -StartOffset 1 `
                -EndOffset 2 `
                -ReplacementText 'B' `
                -Reason 'Replace b' `
                -ExpectedText 'x'
        } | Should -Throw '*Expected source text mismatch at offsets [[]1, 2)*'

        $Document.Edits.Count | Should -Be 0
    }

    It 'returns structured details for both edits in a conflict' {
        $Document = New-AstDocument -InputObject 'abcdef'
        $null = Add-AstTextEdit -Document $Document -StartOffset 1 -EndOffset 4 -ReplacementText 'first' -Reason 'First correction'

        try {
            Add-AstTextEdit -Document $Document -StartOffset 3 -EndOffset 5 -ReplacementText 'second' -Reason 'Second correction'
            throw 'Expected Add-AstTextEdit to reject the overlapping edit.'
        } catch {
            $_.Exception.Data['ExistingEdit'].Reason | Should -Be 'First correction'
            $_.Exception.Data['ExistingEdit'].StartOffset | Should -Be 1
            $_.Exception.Data['IncomingEdit'].Reason | Should -Be 'Second correction'
            $_.Exception.Data['IncomingEdit'].EndOffset | Should -Be 5
        }
    }
}
