Describe 'Binding' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should create a Self relative source binding' {
        $binding = Binding 'IsEnabled' -Self

        $binding.Path.Path | Should -Be -ExpectedValue 'IsEnabled'
        $binding.RelativeSource | Should -Not -BeNullOrEmpty
        $binding.RelativeSource.Mode | Should -Be -ExpectedValue ([System.Windows.Data.RelativeSourceMode]::Self)
    }

    It 'Should create a TemplatedParent relative source binding' {
        $binding = Binding 'IsEnabled' -TemplatedParent

        $binding.Path.Path | Should -Be -ExpectedValue 'IsEnabled'
        $binding.RelativeSource.Mode | Should -Be -ExpectedValue ([System.Windows.Data.RelativeSourceMode]::TemplatedParent)
    }

    It 'Should reject multiple source selectors' {
        {
            Binding 'IsEnabled' -Self -TemplatedParent -ErrorAction Stop
        } | Should -Throw
    }
}
