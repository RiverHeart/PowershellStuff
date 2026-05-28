Describe 'Invoke-BulkReplace' -Tag 'Invoke-BulkReplace' {
    BeforeAll {
        $ScriptPath = (Resolve-Path -Path (Join-Path $PSScriptRoot '../scripts/Invoke-BulkReplace.ps1')).Path
    }

    It 'Applies literal replacement rules across matching files' {
        $RootPath = Join-Path $TestDrive 'ReplacementRoot'
        $NestedPath = Join-Path $RootPath 'Nested'
        New-Item -ItemType Directory -Path $NestedPath -Force | Out-Null

        $FirstFile = Join-Path $RootPath 'FirstCase.Tests.ps1'
        $SecondFile = Join-Path $NestedPath 'SecondCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FirstFile, "Describe 'FirstCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($SecondFile, "Describe 'SecondCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $RootPath -Recurse -Rule @(
            @{ Name = 'Tag FirstCase'; FilePattern = 'FirstCase.Tests.ps1'; Pattern = "Describe 'FirstCase' {"; Replacement = "Describe 'FirstCase' -Tag 'FirstCase' {" }
            @{ Name = 'Tag SecondCase'; FilePattern = 'SecondCase.Tests.ps1'; Pattern = "Describe 'SecondCase' {"; Replacement = "Describe 'SecondCase' -Tag 'SecondCase' {" }
        ) -PassThru -PassThruFormat Detailed

        (Get-Content -Path $FirstFile -Raw) | Should -BeExactly "Describe 'FirstCase' -Tag 'FirstCase' {`r`n}`r`n"
        (Get-Content -Path $SecondFile -Raw) | Should -BeExactly "Describe 'SecondCase' -Tag 'SecondCase' {`r`n}`r`n"
        $Result.Count | Should -Be 2
        @($Result | Where-Object { $_.Changed }).Count | Should -Be 2
        @($Result | Where-Object { $_.WouldChange }).Count | Should -Be 2

        $FirstResult = $Result | Where-Object { $_.Path -eq $FirstFile } | Select-Object -First 1
        $FirstResult | Should -Not -BeNullOrEmpty
        $FirstResult.LineNumbers | Should -Be @(1)
        $FirstResult.Changes[0].LineNumber | Should -Be 1
        $FirstResult.Changes[0].OriginalLine | Should -Be "Describe 'FirstCase' {"
        $FirstResult.Changes[0].ReplacementLine | Should -Be "Describe 'FirstCase' -Tag 'FirstCase' {"
    }

    It 'Returns line-numbered search hits without writing changes' {
        $RootPath = Join-Path $TestDrive 'SearchRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'SearchCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'SearchCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $FilePath -SearchOnly -Rule @(
            @{ Name = 'Find SearchCase'; Pattern = "Describe 'SearchCase' {" }
        ) -PassThru -PassThruFormat Detailed

        $Result.Count | Should -Be 1
        $Result[0].FilePath | Should -Be $FilePath
        $Result[0].LineNumber | Should -Be 1
        $Result[0].LineText | Should -Be "Describe 'SearchCase' {"
    }

    It 'Supports WhatIf without writing changes' {
        $RootPath = Join-Path $TestDrive 'PreviewRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'PreviewCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'PreviewCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $RootPath -Rule @(
            @{ Name = 'Tag PreviewCase'; Pattern = "Describe 'PreviewCase' {"; Replacement = "Describe 'PreviewCase' -Tag 'PreviewCase' {" }
        ) -WhatIf -PassThru -PassThruFormat Detailed

        (Get-Content -Path $FilePath -Raw) | Should -BeExactly "Describe 'PreviewCase' {`r`n}`r`n"
        $Result.Count | Should -Be 1
        $Result[0].Changed | Should -BeFalse
        $Result[0].WouldChange | Should -BeTrue
        $Result[0].LineNumbers | Should -Be @(1)
        $Result[0].Changes.Count | Should -Be 1
    }

    It 'Loads rules from a json file' {
        $RootPath = Join-Path $TestDrive 'RulePathRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'RulePathCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'RulePathCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $RuleFilePath = Join-Path $RootPath 'rules.json'
@'
[
    {
        "Name": "Tag RulePathCase",
        "Pattern": "Describe 'RulePathCase' {",
        "Replacement": "Describe 'RulePathCase' -Tag 'RulePathCase' {"
    }
]
'@ | Set-Content -Path $RuleFilePath -Encoding utf8

        $Result = & $ScriptPath -Path $FilePath -RulePath $RuleFilePath -PassThru

        (Get-Content -Path $FilePath -Raw) | Should -BeExactly "Describe 'RulePathCase' -Tag 'RulePathCase' {`r`n}`r`n"
        $Result.Count | Should -Be 1
        $Result[0].Changed | Should -BeTrue
        $Result[0].AppliedRuleCount | Should -Be 1
    }

    It 'Returns compact search results by default' {
        $RootPath = Join-Path $TestDrive 'SearchSummaryRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'SearchSummaryCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'SearchSummaryCase' {`r`nDescribe 'SearchSummaryCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $FilePath -SearchOnly -Find "Describe 'SearchSummaryCase' {" -PassThru

        $Result.Count | Should -Be 1
        $Result[0].MatchCount | Should -Be 2
        $Result[0].LineNumbers | Should -Be @(1, 2)
    }

    It 'Applies literal ignore-case replacements when requested' {
        $RootPath = Join-Path $TestDrive 'IgnoreCaseRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'IgnoreCaseCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "describe 'IgnoreCaseCase' {`r`nDescribe 'ignorecasecase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $FilePath -Find "Describe 'IgnoreCaseCase' {" -Replace "Describe 'IgnoreCaseCase' -Tag 'IgnoreCaseCase' {" -IgnoreCase -PassThru

        (Get-Content -Path $FilePath -Raw) | Should -BeExactly "Describe 'IgnoreCaseCase' -Tag 'IgnoreCaseCase' {`r`nDescribe 'IgnoreCaseCase' -Tag 'IgnoreCaseCase' {`r`n}`r`n"
        $Result.Count | Should -Be 1
        $Result[0].Changed | Should -BeTrue
        $Result[0].ReplacementCount | Should -Be 2
    }
}
