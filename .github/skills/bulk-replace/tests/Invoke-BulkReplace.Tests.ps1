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

    It 'Returns changed files only by default in summary pass-through' {
        $RootPath = Join-Path $TestDrive 'OnlyChangedDefaultRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $ChangedFilePath = Join-Path $RootPath 'Changed.Tests.ps1'
        $UnchangedFilePath = Join-Path $RootPath 'Unchanged.Tests.ps1'
        [System.IO.File]::WriteAllText($ChangedFilePath, "Describe 'Changed' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($UnchangedFilePath, "Describe 'Unchanged' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $RootPath -Recurse -Find "Describe 'Changed' {" -Replace "Describe 'Changed' -Tag 'Changed' {" -PassThru

        $Result.Count | Should -Be 1
        $Result[0].Path | Should -Be $ChangedFilePath
        $Result[0].Changed | Should -BeTrue
    }

    It 'Can include unchanged files when OnlyChanged is disabled' {
        $RootPath = Join-Path $TestDrive 'OnlyChangedDisabledRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $ChangedFilePath = Join-Path $RootPath 'Changed.Tests.ps1'
        $UnchangedFilePath = Join-Path $RootPath 'Unchanged.Tests.ps1'
        [System.IO.File]::WriteAllText($ChangedFilePath, "Describe 'Changed' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($UnchangedFilePath, "Describe 'Unchanged' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $RootPath -Recurse -Find "Describe 'Changed' {" -Replace "Describe 'Changed' -Tag 'Changed' {" -PassThru -OnlyChanged:$false

        $Result.Count | Should -Be 2
        @($Result | Where-Object { $_.Path -eq $ChangedFilePath }).Count | Should -Be 1
        @($Result | Where-Object { $_.Path -eq $UnchangedFilePath }).Count | Should -Be 1
    }

    It 'Caps detailed search output with MaxMatchesPerFile' {
        $RootPath = Join-Path $TestDrive 'SearchCapRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'SearchCap.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'SearchCap' {`r`nDescribe 'SearchCap' {`r`nDescribe 'SearchCap' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = & $ScriptPath -Path $FilePath -SearchOnly -Find "Describe 'SearchCap' {" -PassThru -PassThruFormat Detailed -MaxMatchesPerFile 2

        $Result.Count | Should -Be 2
        $Result[0].LineNumber | Should -Be 1
        $Result[1].LineNumber | Should -Be 2
    }

    It 'Can emit a run summary object before replace pass-through rows' {
        $RootPath = Join-Path $TestDrive 'ReplaceSummaryRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'ReplaceSummaryCase.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'ReplaceSummaryCase' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = @(& $ScriptPath -Path $FilePath -Find "Describe 'ReplaceSummaryCase' {" -Replace "Describe 'ReplaceSummaryCase' -Tag 'ReplaceSummaryCase' {" -PassThru -IncludeSummaryObject)

        $Result.Count | Should -Be 2
        $Result[0].RecordType | Should -Be 'RunSummary'
        $Result[0].Mode | Should -Be 'Replace'
        $Result[0].ScannedFileCount | Should -Be 1
        $Result[0].ChangedFileCount | Should -Be 1
        $Result[1].Changed | Should -BeTrue
    }

    It 'Can emit a run summary object before search pass-through rows' {
        $RootPath = Join-Path $TestDrive 'SearchSummaryObjectRoot'
        New-Item -ItemType Directory -Path $RootPath -Force | Out-Null

        $FilePath = Join-Path $RootPath 'SearchSummaryObject.Tests.ps1'
        [System.IO.File]::WriteAllText($FilePath, "Describe 'SearchSummaryObject' {`r`n}`r`n", [System.Text.UTF8Encoding]::new($false))

        $Result = @(& $ScriptPath -Path $FilePath -SearchOnly -Find "Describe 'SearchSummaryObject' {" -PassThru -IncludeSummaryObject)

        $Result.Count | Should -Be 2
        $Result[0].RecordType | Should -Be 'RunSummary'
        $Result[0].Mode | Should -Be 'SearchOnly'
        $Result[0].ScannedFileCount | Should -Be 1
        $Result[0].MatchedFileCount | Should -Be 1
        $Result[1].MatchCount | Should -Be 1
    }
}
