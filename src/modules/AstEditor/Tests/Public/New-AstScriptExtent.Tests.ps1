using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'New-AstScriptExtent' {
    It 'creates an exported, offset-aware extent for whitespace and a usable deletion' {
        $Document = New-AstDocument -InputObject '$Value = 1  '
        $Extent = New-AstScriptExtent -Document $Document -StartOffset 10 -EndOffset 12

        $Extent | Should -BeOfType ([IScriptExtent])
        $Extent.StartScriptPosition | Should -BeOfType ([IScriptPosition])
        $Extent.EndScriptPosition | Should -BeOfType ([IScriptPosition])
        $Extent.StartOffset | Should -Be 10
        $Extent.EndOffset | Should -Be 12
        $Extent.StartColumnNumber | Should -Be 11
        $Extent.EndColumnNumber | Should -Be 13
        $Extent.Text | Should -BeExactly '  '
        $Extent.File | Should -BeNullOrEmpty
        $Extent.StartScriptPosition.GetFullScript() | Should -BeExactly $Document.OriginalText
        $Extent.EndScriptPosition.GetFullScript() | Should -BeExactly $Document.OriginalText
        $Document.Edits.Count | Should -Be 0

        $Edit = New-AstTextEdit -Extent $Extent -ReplacementText '' -Reason 'Trim spaces.'
        $Edit.ExpectedText | Should -BeExactly '  '
        Add-AstTextEdit -Document $Document -TextEdit $Edit
        (Resolve-AstDocument -Document $Document -PassThruText).RenderedText |
            Should -BeExactly '$Value = 1'
        $Extent.Text | Should -BeExactly '  '
    }

    It 'maps multiline ranges and EOF with <Name> terminators' -ForEach @(
        @{ Name = 'CRLF'; NewLine = "`r`n" }
        @{ Name = 'LF'; NewLine = "`n" }
        @{ Name = 'CR'; NewLine = "`r" }
    ) {
        $Text = "# first${NewLine}# second${NewLine}"
        $Document = New-AstDocument -InputObject $Text
        $Start = 7 + $NewLine.Length
        $Extent = New-AstScriptExtent -Document $Document -StartOffset $Start -EndOffset $Text.Length

        $Extent.StartLineNumber | Should -Be 2
        $Extent.StartColumnNumber | Should -Be 1
        $Extent.EndLineNumber | Should -Be 3
        $Extent.EndColumnNumber | Should -Be 1
        $Extent.Text | Should -BeExactly "# second${NewLine}"
        $Extent.StartScriptPosition.Line | Should -BeExactly "# second${NewLine}"
        $Extent.EndScriptPosition.Line | Should -BeExactly ''
        $Extent.EndScriptPosition.Offset | Should -Be $Text.Length
    }

    It 'keeps offsets inside CRLF on the preceding line' {
        $Document = New-AstDocument -InputObject "# x`r`n# y"
        $Extent = New-AstScriptExtent -Document $Document -StartOffset 3 -EndOffset 4
        $Extent.Text | Should -BeExactly "`r"
        $Extent.StartLineNumber | Should -Be 1
        $Extent.EndLineNumber | Should -Be 1
        $Extent.StartColumnNumber | Should -Be 4
        $Extent.EndColumnNumber | Should -Be 5
    }

    It 'supports an empty snapshot' {
        $Document = New-AstDocument -InputObject ''
        $Extent = New-AstScriptExtent -Document $Document -StartOffset 0 -EndOffset 0
        $Extent.Text | Should -BeExactly ''
        $Extent.StartOffset | Should -Be 0
        $Extent.EndOffset | Should -Be 0
        $Extent.StartLineNumber | Should -Be 1
        $Extent.EndLineNumber | Should -Be 1
        $Extent.StartColumnNumber | Should -Be 1
        $Extent.EndColumnNumber | Should -Be 1
    }

    It 'matches parser coordinates and provenance in a nested fragment' {
        $Text = "# host`r`n& { `$Value = 1  }`r`n# outside"
        $File = Join-Path $TestDrive 'Source.ps1'
        $Root = [Parser]::ParseInput($Text, $File, [ref] $null, [ref] $null)
        $Fragment = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock
        $Document = New-AstDocument -InputObject $Fragment
        $Extent = New-AstScriptExtent -Document $Document `
            -StartOffset $Fragment.Extent.StartOffset -EndOffset $Fragment.Extent.EndOffset

        foreach ($Property in @(
            'File', 'Text', 'StartOffset', 'EndOffset',
            'StartLineNumber', 'EndLineNumber', 'StartColumnNumber', 'EndColumnNumber'
        )) {
            $Extent.$Property | Should -BeExactly $Fragment.Extent.$Property
        }
        $Extent.StartScriptPosition.Line | Should -BeExactly $Fragment.Extent.StartScriptPosition.Line
        $Extent.StartScriptPosition.GetFullScript() | Should -BeExactly $Text
        $Document.IsFileBacked | Should -BeFalse

        foreach ($Offset in $Extent.StartOffset, $Extent.EndOffset) {
            $Empty = New-AstScriptExtent -Document $Document -StartOffset $Offset -EndOffset $Offset
            $Empty.Text | Should -BeExactly ''
            $Empty.StartOffset | Should -Be $Offset
            $Empty.EndOffset | Should -Be $Offset
        }

        foreach ($Range in @(
            @{ Start = 0; End = $Extent.StartOffset }
            @{ Start = $Extent.EndOffset; End = $Text.Length }
        )) {
            $Failure = $null
            try {
                New-AstScriptExtent -Document $Document -StartOffset $Range.Start -EndOffset $Range.End
            } catch {
                $Failure = $_
            }
            $Failure | Should -Not -BeNullOrEmpty
            $Failure.Exception.Data['FailureKind'] | Should -BeExactly 'OutsideTarget'
        }
    }

    It 'rejects invalid offsets: <Start>, <End>' -ForEach @(
        @{ Start = -1; End = 0 }
        @{ Start = 2; End = 1 }
        @{ Start = 0; End = 4 }
    ) {
        $Document = New-AstDocument -InputObject '# x'
        { New-AstScriptExtent -Document $Document -StartOffset $Start -EndOffset $End } |
            Should -Throw
    }

    It 'counts UTF-16 offsets and handles mixed line endings without normalization' {
        $Text = '# ' + [char]::ConvertFromUtf32(0x1F600) + "  `r`n# next`n# last`r"
        $Document = New-AstDocument -InputObject $Text
        $Extent = New-AstScriptExtent -Document $Document -StartOffset 4 -EndOffset 6
        $Extent.Text | Should -BeExactly '  '
        $Extent.StartColumnNumber | Should -Be 5
        $Extent.EndColumnNumber | Should -Be 7
        $End = New-AstScriptExtent -Document $Document -StartOffset $Text.Length -EndOffset $Text.Length
        $End.StartLineNumber | Should -Be 4
        $End.StartColumnNumber | Should -Be 1
    }
}
