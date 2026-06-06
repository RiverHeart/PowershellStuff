Describe 'ConvertTo-KeyGesture' -Tag 'ConvertTo-KeyGesture' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should convert a single gesture string into a KeyGesture' {
        $Result = ConvertTo-KeyGesture -InputObject 'Ctrl+Shift+S'

        @($Result).Count | Should -Be 1
        $Result[0] | Should -BeOfType [System.Windows.Input.KeyGesture]
        $Result[0].Key | Should -Be ([System.Windows.Input.Key]::S)
    }

    It 'Should convert multiple gesture strings into KeyGesture objects' {
        $Result = ConvertTo-KeyGesture -InputObject @('Ctrl+S', 'F11')

        @($Result).Count | Should -Be 2
        $Result[0].Key | Should -Be ([System.Windows.Input.Key]::S)
        $Result[1].Key | Should -Be ([System.Windows.Input.Key]::F11)
    }

    It 'Should throw for an invalid gesture string' {
        { ConvertTo-KeyGesture -InputObject 'TotallyNotAGesture' -ErrorAction Stop } | Should -Throw
    }
}
