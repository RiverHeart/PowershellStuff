Describe 'Test-PSType' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-PSType.ps1"
        . "$PSScriptRoot/../functions/Test-PSType.ps1"
    }

    It 'Should return false for an untagged object' {
        $Target = [System.Windows.Controls.Label]::new()

        Test-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type' | Should -Be -ExpectedValue $false
    }

    It 'Should return true when any of multiple type names match' {
        $Target = [System.Windows.Controls.Label]::new()
        Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type'

        Test-PSType -InputObject $Target -TypeName @('Other.Type', 'Some.Arbitrary.Type') | Should -Be -ExpectedValue $true
    }

    It 'Should return false when none of multiple type names match' {
        $Target = [System.Windows.Controls.Label]::new()
        Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type'

        Test-PSType -InputObject $Target -TypeName @('Other.Type', 'Another.Type') | Should -Be -ExpectedValue $false
    }
}
