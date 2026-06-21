Describe 'Find-WPFChildNode' -Tag 'Find-WPFChildNode' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeAll {
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should return the same object when node matches requested type' {
        $Path = [System.Windows.Shapes.Path]::new()

        $Found = Find-WPFChildNode -Node $Path -Type ([System.Windows.Shapes.Path])

        $Found | Should -BeExactly -ExpectedValue $Path
    }

    It 'Should find first matching descendant by type' {
        $First = [System.Windows.Shapes.Path]::new()
        $Second = [System.Windows.Shapes.Path]::new()
        $Border = [System.Windows.Controls.Border]::new()
        $Panel = [System.Windows.Controls.StackPanel]::new()

        $Border.Child = $First
        $null = $Panel.Children.Add($Border)
        $null = $Panel.Children.Add($Second)

        $Found = Find-WPFChildNode -Node $Panel -Type ([System.Windows.Shapes.Path])

        $Found | Should -BeExactly -ExpectedValue $First
    }

    It 'Should return all matching descendants with -All' {
        $First = [System.Windows.Shapes.Path]::new()
        $Second = [System.Windows.Shapes.Path]::new()
        $Panel = [System.Windows.Controls.StackPanel]::new()

        $null = $Panel.Children.Add($First)
        $null = $Panel.Children.Add([System.Windows.Controls.Label]::new())
        $null = $Panel.Children.Add($Second)

        $Found = Find-WPFChildNode -Node $Panel -Type ([System.Windows.Shapes.Path]) -All

        @($Found).Count | Should -Be -ExpectedValue 2
        $Found[0] | Should -BeExactly -ExpectedValue $First
        $Found[1] | Should -BeExactly -ExpectedValue $Second
    }

    It 'Should return null when no matching node exists' {
        $Label = [System.Windows.Controls.Label]::new()

        $Found = Find-WPFChildNode -Node $Label -Type ([System.Windows.Shapes.Path])

        $Found | Should -BeNullOrEmpty
    }
}
