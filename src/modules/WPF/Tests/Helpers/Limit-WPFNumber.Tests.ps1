Describe 'Limit-WPFNumber' -Tag 'Limit-WPFNumber' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    It 'Should return the value unchanged when within bounds' {
        Limit-WPFNumber -Value 50 -Minimum 20 -Maximum 100 | Should -Be -ExpectedValue 50
    }

    It 'Should clamp to the minimum when below it' {
        Limit-WPFNumber -Value 5 -Minimum 20 -Maximum 100 | Should -Be -ExpectedValue 20
    }

    It 'Should clamp to the maximum when above it' {
        Limit-WPFNumber -Value 500 -Minimum 20 -Maximum 100 | Should -Be -ExpectedValue 100
    }

    It 'Should default to an unbounded minimum' {
        Limit-WPFNumber -Value -500 -Maximum 100 | Should -Be -ExpectedValue -500
    }

    It 'Should default to an unbounded maximum' {
        Limit-WPFNumber -Value 5000 -Minimum 20 | Should -Be -ExpectedValue 5000
    }
}
