Describe 'Get-WPFFileSelection' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It "Should throw when -Type 'All' is combined with -Category" {
        {
            Get-WPFFileSelection -Type All -Category Image -ErrorAction Stop
        } | Should -Throw -ExpectedMessage "*cannot be combined with -Category*"
    }

    It 'Should return empty when no filters are resolved' {
        InModuleScope WPF {
            Mock -CommandName Get-WPFFileInfo -MockWith {
                @{ Display = 'MissingFilter' }
            }

            $Result = Get-WPFFileSelection -Category Image -ErrorAction SilentlyContinue

            Should -Invoke -CommandName Get-WPFFileInfo -Times 2 -Exactly
            $Result | Should -Be -ExpectedValue ''
        }
    }
}
