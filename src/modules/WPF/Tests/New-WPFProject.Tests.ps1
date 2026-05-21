Describe 'New-WPFProject' -Tag 'New-WPFProject' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Creates non-bare scaffold with a supported horizontal starter button row' {
        $ProjectRoot = Join-Path $TestDrive 'StarterApp'

        $Result = New-WPFProject -Name 'StarterApp' -Path $TestDrive

        $Result.ProjectRoot | Should -Be $ProjectRoot
        Test-Path -Path $Result.DslScript | Should -BeTrue
        Test-Path -Path $Result.StyleScript | Should -BeTrue

        $DslContent = Get-Content -Path $Result.DslScript -Raw
        $DslContent | Should -Match "StackPanel 'StarterButtonRow'"
        $DslContent | Should -Match "Orientation\]::Horizontal"
    }

    It 'Seeds starter style palette in generated style file' {
        $Result = New-WPFProject -Name 'PaletteApp' -Path $TestDrive

        $StyleContent = Get-Content -Path $Result.StyleScript -Raw

        $StyleContent | Should -Match "Style Button"
        $StyleContent | Should -Match "Style 'PrimaryButton' Button"
        $StyleContent | Should -Match "Style 'DangerButton' Button"
        $StyleContent | Should -Match "Style 'GhostButton' Button"
    }
}
