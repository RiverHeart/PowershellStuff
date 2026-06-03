BeforeAll {
    . "$PSScriptRoot/../Public/Get-Frontmatter.ps1"
}

Describe 'Get-Frontmatter' {
    It 'parses key-value metadata using inferred PowerShell style' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'sample.ps1'
        Set-Content -Path $Path -Encoding UTF8 -Value @(
            '<#Metadata'
            'Name=Demo'
            '#>'
            "Write-Host 'x'"
        )

        $Result = Get-Frontmatter -Path $Path -InputFormat KeyValuePair

        $Result | Should -Not -BeNullOrEmpty
        $Result['Name'] | Should -Be 'Demo'
    }

    It 'parses key-value metadata using inferred Yaml style' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'sample.yaml'
        Set-Content -Path $Path -Encoding UTF8 -Value @(
            '---'
            'Name: Demo'
            '---'
            "Key: Value"
        )

        $Result = Get-Frontmatter -Path $Path -InputFormat KeyValuePair

        $Result | Should -Not -BeNullOrEmpty
        $Result['Name'] | Should -Be 'Demo'
    }

    It 'ignores leading blank lines before frontmatter' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'leading-blank-lines.ps1'
        Set-Content -Path $Path -Encoding UTF8 -Value @(
            ''
            ''
            '<#Metadata'
            'Name=Demo'
            '#>'
            "Write-Host 'x'"
        )

        $Result = Get-Frontmatter -Path $Path -InputFormat KeyValuePair

        $Result['Name'] | Should -Be 'Demo'
    }

    It 'parses PowerShellData metadata as hashtable' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'psdata.ps1'
        Set-Content -Path $Path -Encoding UTF8 -Value @(
            '<#Metadata'
            '@{ Name = ''Demo''; Count = 2 }'
            '#>'
        )

        $Result = Get-Frontmatter -Path $Path -InputFormat PowerShellData

        $Result | Should -BeOfType ([hashtable])
        $Result['Name'] | Should -Be 'Demo'
        $Result['Count'] | Should -Be 2
    }

    It 'writes an error when frontmatter end marker is missing' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'missing-end.ps1'
        Set-Content -Path $Path -Encoding UTF8 -Value @(
            '<#Metadata'
            'Name=Demo'
            "Write-Host 'x'"
        )

        $Error.Clear()
        $Result = Get-Frontmatter -Path $Path -ErrorAction SilentlyContinue

        $Result | Should -BeNullOrEmpty
        @($Error).Count | Should -BeGreaterThan 0
        @($Error)[0].ToString() | Should -Match 'end marker'
    }

    It 'writes an error when custom metadata style has empty delimiters' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'custom-style-invalid.ps1'
        Set-Content -Path $Path -Encoding UTF8 -Value @(
            '<#Metadata'
            'Name=Demo'
            '#>'
        )

        $Error.Clear()
        $Result = Get-Frontmatter -Path $Path -MetadataStyle @{ Start = ''; End = '#>' } -ErrorAction SilentlyContinue

        $Result | Should -BeNullOrEmpty
        @($Error).Count | Should -BeGreaterThan 0
        @($Error)[0].ToString() | Should -Match 'must be non-empty strings'
    }
}
