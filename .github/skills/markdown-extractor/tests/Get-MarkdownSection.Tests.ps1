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

## Intro
second
'@ | Set-Content -Path $markdownPath -Encoding utf8

        $warnings = $null
        $result = Get-MarkdownSection -Path $markdownPath -Section intro -Content -WarningVariable warnings

        @($warnings).Count | Should -Be 1
        @($warnings)[0].Message | Should -Match 'Returning the first match only'
        @($result) | Should -Be @('first', '')
    }
}
