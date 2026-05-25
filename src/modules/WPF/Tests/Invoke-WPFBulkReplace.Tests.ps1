Describe 'Invoke-WPFBulkReplace' -Tag 'Invoke-WPFBulkReplace' {
    BeforeAll {
        $ScriptPath = Join-Path $PSScriptRoot '../Scripts/Invoke-WPFBulkReplace.ps1'
    }

    It 'Applies literal replacement rules across matching files' {
        $RootPath = Join-Path $TestDrive 'ReplacementRoot'
        $NestedPath = Join-Path $RootPath 'Nested'
        New-Item -ItemType Directory -Path $NestedPath -Force | Out-Null

        $FirstFile = Join-Path $RootPath 'Binding.Tests.ps1'
        $SecondFile = Join-Path $NestedPath 'Button.Tests.ps1'
        [System.IO.File]::WriteAllText($FirstFile, "Describe 'Binding' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($SecondFile, "Describe 'Button' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $RootPath -Recurse -Rule @(
            @{ Name = 'Tag Binding'; FilePattern = 'Binding.Tests.ps1'; Pattern = "Describe 'Binding' {"; Replacement = "Describe 'Binding' -Tag 'Binding' {" }
            @{ Name = 'Tag Button'; FilePattern = 'Button.Tests.ps1'; Pattern = "Describe 'Button' {"; Replacement = "Describe 'Button' -Tag 'Button' {" }
        ) -PassThru -PassThruFormat Detailed

        (Get-Content -Path $FirstFile -Raw) | Should -BeExactly "Describe 'Binding' -Tag 'Binding' {`r`n}`r`n"
        (Get-Content -Path $SecondFile -Raw) | Should -BeExactly "Describe 'Button' -Tag 'Button' {`r`n}`r`n"
        $Result.Count | Should -Be 2
        @($Result | Where-Object { $_.Changed }).Count | Should -Be 2
        @($Result | Where-Object { $_.WouldChange }).Count | Should -Be 2
        $Result[0].LineNumbers | Should -Be @(1)
        $Result[0].Changes[0].LineNumber | Should -Be 1
        $Result[0].Changes[0].OriginalLine | Should -Be "Describe 'Binding' {"
        $Result[0].Changes[0].ReplacementLine | Should -Be "Describe 'Binding' -Tag 'Binding' {"
    }

    It 'Returns line-numbered search hits without writing changes' {
        $RootPath = Join-Path $TestDrive 'SearchRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'Column.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'Column' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $FilePath -SearchOnly -Rule @(
            @{ Name = 'Find Column'; Pattern = "Describe 'Column' {" }
        ) -PassThru -PassThruFormat Detailed

        $Result.Count | Should -Be 1
        $Result[0].FilePath | Should -Be $FilePath
        $Result[0].LineNumber | Should -Be 1
        $Result[0].LineText | Should -Be "Describe 'Column' {"
    }

    It 'Supports WhatIf without writing changes' {
        $RootPath = Join-Path $TestDrive 'PreviewRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'State.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'State' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $RootPath -Rule @(
            @{ Name = 'Tag State'; Pattern = "Describe 'State' {"; Replacement = "Describe 'State' -Tag 'State' {" }
        ) -WhatIf -PassThru -PassThruFormat Detailed

        (Get-Content -Path $FilePath -Raw) | Should -BeExactly "Describe 'State' {`r`n}`r`n"
        $Result.Count | Should -Be 1
        $Result[0].Changed | Should -BeFalse
        $Result[0].WouldChange | Should -BeTrue
        $Result[0].LineNumbers | Should -Be @(1)
        $Result[0].Changes.Count | Should -Be 1
    }

    It 'Loads rules from a json file' {
        $RootPath = Join-Path $TestDrive 'RulePathRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'Theme.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'Theme' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $RuleFilePath = Join-Path $RootPath 'rules.json'
@'
[
    {
        "Name": "Tag Theme",
        "Pattern": "Describe 'Theme' {",
        "Replacement": "Describe 'Theme' -Tag 'Theme' {"
    }
]
'@ | Set-Content -Path $RuleFilePath -Encoding utf8

        $Result = & $ScriptPath -Path $FilePath -RulePath $RuleFilePath -PassThru

        (Get-Content -Path $FilePath -Raw) | Should -BeExactly "Describe 'Theme' -Tag 'Theme' {`r`n}`r`n"
        $Result.Count | Should -Be 1
        $Result[0].Changed | Should -BeTrue
        $Result[0].AppliedRuleCount | Should -Be 1
    }

    It 'Returns compact search results by default' {
        $RootPath = Join-Path $TestDrive 'SearchSummaryRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'Grid.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'Grid' {`r`nDescribe 'Grid' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $FilePath -SearchOnly -Find "Describe 'Grid' {" -PassThru

        $Result.Count | Should -Be 1
        $Result[0].MatchCount | Should -Be 2
        $Result[0].LineNumbers | Should -Be @(1, 2)
    }
}
