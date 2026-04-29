Describe 'Border DSL' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should create and auto-attach a named border' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            Border "Border_$Id" {
                $this.Padding = 4
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -BeOfType [System.Windows.Controls.Border]
        $Parent.Content.Name | Should -Be -ExpectedValue "Border_$Id"
        $Parent.Content.Padding.Left | Should -Be -ExpectedValue 4
    }

    It 'Should support nameless border syntax' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.Button]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            Border {
                Label "BorderChild_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -BeOfType [System.Windows.Controls.Border]
        $Parent.Content.Child | Should -BeOfType [System.Windows.Controls.Label]
        $Parent.Content.Child.Name | Should -Be -ExpectedValue "BorderChild_$Id"
    }
}

Describe 'Find-WPFChildPath' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should return the same object when node is already a Path' {
        $Path = [System.Windows.Shapes.Path]::new()
        $Found = Find-WPFChildPath -Node $Path

        $Found | Should -BeExactly -ExpectedValue $Path
    }

    It 'Should find a nested path under content and child properties' {
        $Path = [System.Windows.Shapes.Path]::new()
        $Border = [System.Windows.Controls.Border]::new()
        $Button = [System.Windows.Controls.Button]::new()

        $Border.Child = $Path
        $Button.Content = $Border

        $Found = Find-WPFChildPath -Node $Button
        $Found | Should -BeExactly -ExpectedValue $Path
    }

    It 'Should return null when no path exists' {
        $Label = [System.Windows.Controls.Label]::new()
        $Found = Find-WPFChildPath -Node $Label

        $Found | Should -BeNullOrEmpty
    }
}

Describe 'When' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should inject this as the current object when event fires' {
        $global:WhenThisName = $null

        $Name = "WhenButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            When Click {
                $global:WhenThisName = $this.Name
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $global:WhenThisName | Should -Be -ExpectedValue $Name

        Remove-Variable -Name WhenThisName -Scope Global -ErrorAction SilentlyContinue
    }
}
