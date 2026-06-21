Describe 'On' -Tag 'On', 'Category:Events' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    BeforeAll {
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should inject this as the current object when event fires' {
        $global:OnThisName = $null

        $Name = "OnButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            On Click {
                $global:OnThisName = $this.Name
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $global:OnThisName | Should -Be -ExpectedValue $Name

        Remove-Variable -Name OnThisName -Scope Global -ErrorAction SilentlyContinue
    }
}
