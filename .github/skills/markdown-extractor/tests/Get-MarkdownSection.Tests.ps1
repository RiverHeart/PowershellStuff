Describe 'Get-MarkdownSection' -Tag 'Get-MarkdownSection' {
    BeforeAll {
        $script:ScriptPath = (Resolve-Path -Path (Join-Path $PSScriptRoot '../scripts/Get-MarkdownSection.ps1')).Path
        . $script:ScriptPath
    }

    It 'Returns section objects with ContentLineCount in default mode' {
        $markdownPath = Join-Path $TestDrive 'default-mode.md'
@'
# Title
alpha
beta

## Next
gamma
'@ | Set-Content -Path $markdownPath -Encoding utf8

        $result = @(Get-MarkdownSection -Path $markdownPath)

        $result.Count | Should -Be 2
        $result[0].Section | Should -Be 'title'
        $result[0].ContentLineCount | Should -Be 3
        $result[0].LineStart | Should -Be 2
        $result[0].LineEnd | Should -Be 4
        $result[1].Section | Should -Be 'next'
        $result[1].ContentLineCount | Should -Be 1
    }

    It 'Supports ValueFromPipelineByPropertyName for Path' {
        $markdownPath = Join-Path $TestDrive 'pipeline-path.md'
@'
# One
body
'@ | Set-Content -Path $markdownPath -Encoding utf8

        $result = @([pscustomobject]@{ Path = $markdownPath } | Get-MarkdownSection -Name)

        $result | Should -Be @('one')
    }

    It 'Returns raw content as a single string with RawContent' {
        $markdownPath = Join-Path $TestDrive 'raw-content.md'
@'
# Intro
line one
line two
'@ | Set-Content -Path $markdownPath -Encoding utf8

        $result = Get-MarkdownSection -Path $markdownPath -Section intro -RawContent

        $result.GetType().Name | Should -Be 'String'
        $result | Should -Be ('line one' + [Environment]::NewLine + 'line two')
    }

    It 'Warns on duplicate slugs and returns the first match only' {
        $markdownPath = Join-Path $TestDrive 'duplicate.md'
@'
# Intro
first

# Intro
second
'@ | Set-Content -Path $markdownPath -Encoding utf8

        $warnings = $null
        $result = Get-MarkdownSection -Path $markdownPath -Section intro -Content -WarningVariable warnings

        @($warnings).Count | Should -Be 1
        @($warnings)[0].Message | Should -Match 'Returning the first match only'
        @($result) | Should -Be @('first', '')
    }

    It 'Includes nested headings and bodies without consuming the next sibling or ancestor' {
        $markdownPath = Join-Path $TestDrive 'nested.md'
@'
# Title
intro
## Phase 5
### Overview
overview text
#### Details
detail text
### Work
work text
## Phase 6
next phase
# Appendix
appendix text
'@ | Set-Content -LiteralPath $markdownPath -Encoding utf8

        @(Get-MarkdownSection -Path $markdownPath -Name) | Should -Be @(
            'title', 'phase-5', 'overview', 'details', 'work', 'phase-6', 'appendix'
        )
        $result = Get-MarkdownSection -Path $markdownPath -Section phase-5
        $result.Content.Count | Should -Be 0
        @($result.GetContent()) | Should -Be @(
            '### Overview', 'overview text', '#### Details', 'detail text', '### Work', 'work text'
        )
        $result.LineStart | Should -Be 4
        $result.LineEnd | Should -Be 3
        $result.ContentLineCount | Should -Be 0
        $result.Depth | Should -Be 2
        @($result.Sections.Section) | Should -Be @('overview', 'work')
        $result.Sections[0].Sections[0].Section | Should -Be 'details'
        @(Get-MarkdownSection -Path $markdownPath -Section work -Content) | Should -Be @('work text')
    }

    It 'Filters nested slugs case-insensitively and supports raw parent content' {
        $markdownPath = Join-Path $TestDrive 'raw-parent.md'
        [System.IO.File]::WriteAllText($markdownPath, "# Parent`n## Child`nbody")

        Get-MarkdownSection -Path $markdownPath -Section PARENT -RawContent |
            Should -Be ("## Child" + [Environment]::NewLine + 'body')
        @(Get-MarkdownSection -Path $markdownPath -Section CHILD -Name) | Should -Be @('child')
    }

    It 'Warns for duplicate nested slugs while retaining the full first parent' {
        $markdownPath = Join-Path $TestDrive 'nested-duplicates.md'
        [System.IO.File]::WriteAllText($markdownPath, "# Intro`nfirst`n## Intro`nsecond")

        $warnings = $null
        $result = @(Get-MarkdownSection -Path $markdownPath -Section intro -Content -WarningVariable warnings)

        @($warnings).Count | Should -Be 1
        $result | Should -Be @('first', '## Intro', 'second')
    }

    It 'Reports missing files and sections explicitly' {
        { Get-MarkdownSection -Path (Join-Path $TestDrive 'missing.md') -ErrorAction Stop } |
            Should -Throw '*File not found*'
        $markdownPath = Join-Path $TestDrive 'missing-section.md'
        Set-Content -LiteralPath $markdownPath -Value '# Present'
        { Get-MarkdownSection -Path $markdownPath -Section absent -Content -ErrorAction Stop } |
            Should -Throw '*Section not found*'
    }
}

Describe 'MarkdownDocument' -Tag 'Get-MarkdownSection' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\scripts\Get-MarkdownSection.ps1')
    }

    It 'Returns a single document with nested sections and a separately flattened list' {
        $documents = @(New-MarkdownDocument -Text "# Root`n## Child`n#### Deep`nbody`n## Sibling`n# Next")

        $documents.Count | Should -Be 1
        $document = $documents[0]
        $document.GetType().Name | Should -Be 'MarkdownDocument'
        @($document.Sections.Section) | Should -Be @('root', 'next')
        @($document.Sections[0].Sections.Section) | Should -Be @('child', 'sibling')
        $document.Sections[0].Sections[0].Sections[0].Depth | Should -Be 4
        @($document.GetSections().Section) | Should -Be @('root', 'child', 'deep', 'sibling', 'next')
        $document.Sections[1].Content.Count | Should -Be 0
        $document.Sections[1].LineStart | Should -Be 7
        $document.Sections[1].LineEnd | Should -Be 6
    }

    It 'Does not detect headings inside fenced code, including before the first section' {
        $text = @'
```
# Not a section
```
## Real
````powershell
### Not a child
````
### Child
text
## Next
'@
        $document = New-MarkdownDocument -Text $text

        @($document.GetSections().Section) | Should -Be @('real', 'child', 'next')
        @($document.Sections[0].Content) | Should -Be @(
            '````powershell', '### Not a child', '````'
        )
        $document.Sections[0].LineStart | Should -Be 5
        $document.Sections[0].LineEnd | Should -Be 7
        $document.ToString() | Should -BeExactly ($text -replace '\r\n|\r|\n', [Environment]::NewLine)
    }

    It 'Supports empty or heading-free source without inventing sections' -ForEach @(
        @{ Text = '' }
        @{ Text = "preamble`nbody`n" }
    ) {
        $document = New-MarkdownDocument -Text $Text
        $document.Sections.Count | Should -Be 0
        @($document.GetSections()).Count | Should -Be 0
        $document.ToString() | Should -BeExactly ($Text -replace '\r\n|\r|\n', [Environment]::NewLine)
    }

    It 'Treats headings deeper than MaxDepth as content rather than discarding their bodies' {
        $document = New-MarkdownDocument -Text ''
        $reader = [System.IO.StringReader]::new("# Root`n## Child`n### Deep`nbody`n## Sibling`nend")
        try {
            $document.ParseStream($reader, 2)
            @($document.GetSections().Section) | Should -Be @('root', 'child', 'sibling')
            @($document.Sections[0].Sections[0].Content) | Should -Be @('### Deep', 'body')
            $document.Sections[0].Sections[0].LineEnd | Should -Be 4
            $reader.Peek() | Should -Be -1
        } finally {
            $reader.Dispose()
        }
    }

    It 'Parses a TextReader without closing it or requiring EndOfStream' {
        $reader = [System.IO.StringReader]::new("## Start`nbody`n# End")
        try {
            $document = New-MarkdownDocument -Text ''
            $document.ParseStream($reader)
            @($document.GetSections().Section) | Should -Be @('start', 'end')
            $reader.Peek() | Should -Be -1
        } finally {
            $reader.Dispose()
        }
    }

    It 'Resets sections and file metadata when a document is parsed again' {
        $path = Join-Path $TestDrive 'reparse.md'
        Set-Content -LiteralPath $path -Value '# File'
        $document = New-MarkdownDocument -Path $path
        $document.FileInfo.FullName | Should -Be $path

        $document.ParseString("## Replacement`nbody")
        $document.FileInfo | Should -BeNullOrEmpty
        @($document.GetSections().Section) | Should -Be @('replacement')
        $document.Sections[0].LineStart | Should -Be 2
        $document.Sections[0].LineEnd | Should -Be 2
    }

    It 'Preserves preamble, blank lines, heading depths, and final newline presence when saving' -ForEach @(
        @{ Text = "preamble`r`n# Root`r`n## Child`r`nbody`r`n" }
        @{ Text = "preamble`n## Root`n#### Child`nbody" }
        @{ Text = '' }
        @{ Text = "`n`n# Root  `n`nbody`n`n## Child`n`n" }
        @{ Text = "`n" }
    ) {
        $path = Join-Path $TestDrive 'saved.md'
        $document = New-MarkdownDocument -Text $Text
        $document.Save($path)

        $expected = $Text -replace '\r\n|\r|\n', [Environment]::NewLine
        $document.ToString() | Should -BeExactly $expected
        [System.IO.File]::ReadAllText($path) | Should -BeExactly $expected
    }

    It 'Serializes edited direct content and headers exactly once without changing sibling content' {
        $document = New-MarkdownDocument -Text "preamble`n`n# Root`nintro`n## Child`nold`n### Grandchild`ndeep`n## Sibling`nkeep`n# End`nend"
        $root = $document.Sections[0]
        $child = $root.Sections[0]
        $document.Preamble[0] = 'edited preamble'
        $root.Content[0] = 'edited intro'
        $child.Header = '## Renamed child'
        $child.Content[0] = 'new'
        $child.Content.Add('added')
        $child.ContentLineCount | Should -Be 2
        $child.Sections[0].Content[0] = 'edited deep'

        $expected = @(
            'edited preamble', '', '# Root', 'edited intro', '## Renamed child',
            'new', 'added', '### Grandchild', 'edited deep', '## Sibling', 'keep', '# End', 'end'
        ) -join [Environment]::NewLine
        $document.ToString() | Should -BeExactly $expected
        @($root.GetContent()) | Should -Be @(
            'edited intro', '## Renamed child', 'new', 'added', '### Grandchild',
            'edited deep', '## Sibling', 'keep'
        )

        $path = Join-Path $TestDrive 'edited.md'
        $document.Save($path)
        [System.IO.File]::ReadAllText($path) | Should -BeExactly $expected
        $reparsed = New-MarkdownDocument -Path $path
        @($reparsed.Sections[0].Sections[0].Content) | Should -Be @('new', 'added')
        @($reparsed.GetSections().Section) | Should -Be @('root', 'renamed-child', 'grandchild', 'sibling', 'end')
        $reparsed.ToString() | Should -BeExactly $expected
    }

    It 'Serializes removals and reordered sections from the current tree' {
        $document = New-MarkdownDocument -Text "# Root`n## First`none`n## Second`ntwo`n## Third`nthree`n"
        $children = $document.Sections[0].Sections
        $children.RemoveAt(1)
        $first = $children[0]
        $children.RemoveAt(0)
        $children.Add($first)

        $document.ToString() | Should -BeExactly (
            @('# Root', '## Third', 'three', '## First', 'one', '') -join [Environment]::NewLine
        )
    }

    It 'Resets preamble and final newline state on reparse' {
        $document = New-MarkdownDocument -Text "old preamble`n# Old`n"
        $document.ParseString('# New')

        $document.Preamble.Count | Should -Be 0
        $document.ToString() | Should -BeExactly '# New'
    }

    It 'Supports literal file paths and pipeline property binding' {
        $path = Join-Path $TestDrive 'document[1].md'
        [System.IO.File]::WriteAllText($path, "# Root`nbody")
        $document = [pscustomobject]@{ Path = $path } | New-MarkdownDocument

        $document.FileInfo.FullName | Should -Be $path
        $document.Sections[0].Section | Should -Be 'root'
        @([pscustomobject]@{ Path = $path } | Get-MarkdownSection -Name) | Should -Be @('root')
    }

    It 'Rejects missing files and invalid maximum depths' {
        { New-MarkdownDocument -Path (Join-Path $TestDrive 'absent.md') } |
            Should -Throw '*File not found*'
        $document = New-MarkdownDocument -Text ''
        $reader = [System.IO.StringReader]::new('# Heading')
        try {
            { $document.ParseStream($reader, -1) } | Should -Throw '*MaxDepth*'
            { $document.ParseStream($reader, 7) } | Should -Throw '*MaxDepth*'
        } finally {
            $reader.Dispose()
        }
    }
}
