Describe 'New-WPFProject' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should create a generic scaffold structure' {
        $Result = New-WPFProject 'SampleApp' $TestDrive
        $Root = Join-Path $TestDrive 'SampleApp'

        $Result.ProjectRoot | Should -Be -ExpectedValue $Root
        (Test-Path $Root) | Should -BeTrue
        (Test-Path (Join-Path $Root 'functions')) | Should -BeTrue
        (Test-Path (Join-Path $Root 'images')) | Should -BeTrue
        (Test-Path (Join-Path $Root 'SampleApp.DSL.ps1')) | Should -BeTrue
        (Test-Path (Join-Path $Root 'SampleApp.Styles.ps1')) | Should -BeTrue
        (Test-Path (Join-Path $Root 'README.md')) | Should -BeTrue

        $Dsl = Get-Content -Path (Join-Path $Root 'SampleApp.DSL.ps1') -Raw
        $Dsl | Should -Match ([regex]::Escape('Import "$PSScriptRoot/SampleApp.Styles.ps1"'))
        $Dsl | Should -Match ([regex]::Escape('Import "$PSScriptRoot/functions"'))
        $Dsl | Should -Match "Window 'Window'"
        $Dsl | Should -Match "MenuItem '\(F\)ile/\(Q\)uit'"
        $Dsl | Should -Match "# Uncomment this block to add window-wide keyboard shortcuts\."
    }

    It 'Should create a more minimal scaffold when Bare is set' {
        $Root = Join-Path $TestDrive 'BareApp'

        $null = New-WPFProject 'BareApp' $TestDrive -Bare

        $Dsl = Get-Content -Path (Join-Path $Root 'BareApp.DSL.ps1') -Raw
        $Dsl | Should -Match "Window 'Window'"
        $Dsl | Should -Not -Match "MenuBar 'Menu'"
        $Dsl | Should -Match 'Replace this placeholder with your app content'
    }

    It 'Should throw when target exists without Force' {
        $null = New-WPFProject 'ExistingApp' $TestDrive

        {
            New-WPFProject 'ExistingApp' $TestDrive
        } | Should -Throw -ExpectedMessage '*already exists*'
    }

    It 'Should overwrite scaffold files when Force is set' {
        $Root = Join-Path $TestDrive 'ForceApp'
        $StylePath = Join-Path $Root 'ForceApp.Styles.ps1'

        $null = New-WPFProject 'ForceApp' $TestDrive
        'custom' | Set-Content -Path $StylePath -Encoding UTF8

        $null = New-WPFProject 'ForceApp' $TestDrive -Force
        $StyleContent = Get-Content -Path $StylePath -Raw
        $StyleContent | Should -Match 'Add theme, brush, and style definitions'
    }
}
