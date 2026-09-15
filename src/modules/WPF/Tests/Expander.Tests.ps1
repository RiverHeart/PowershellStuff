Describe 'Expander' -Tag 'Expander' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Creates a named Expander with configured properties' {
        $Result = Expander 'Details' {
            $this.Header = 'More details'
            $this.IsExpanded = $true
        }

        $Result | Should -BeOfType ([System.Windows.Controls.Expander])
        $Result.Name | Should -Be 'Details'
        $Result.Header | Should -Be 'More details'
        $Result.IsExpanded | Should -BeTrue
    }

    It 'Assigns a nested control as its content' {
        $Result = Expander {
            TextBlock 'DetailsText' {
                $this.Text = 'More information'
            }
        }

        $Result.Content | Should -BeOfType ([System.Windows.Controls.TextBlock])
        $Result.Content.Name | Should -Be 'DetailsText'
        $Result.Content.Text | Should -Be 'More information'
    }

    It 'Auto-attaches to a parent and returns no output' {
        $Parent = [System.Windows.Controls.StackPanel]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Expander 'NestedExpander' {}
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 0
        $Parent.Children | Should -HaveCount 1
        $Parent.Children[0] | Should -BeOfType ([System.Windows.Controls.Expander])
        $Parent.Children[0].Name | Should -Be 'NestedExpander'
    }
}
