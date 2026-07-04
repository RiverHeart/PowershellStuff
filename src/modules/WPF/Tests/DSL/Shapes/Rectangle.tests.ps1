Describe 'Rectangle' -Tag 'Rectangle' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should create a Rectangle and auto-attach it to a Border' {
        $border = [System.Windows.Controls.Border]::new()

        $psVars = New-WPFVariableList -InputObject $border
        {
            Rectangle 'GradientBannerFill' {
                $this.Width = 200
                $this.Height = 100
                $this.Fill = LinearGradientBrush {
                    $this.StartPoint = '0,0'
                    $this.EndPoint = '1,1'
                    $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('Yellow', 0.0))
                    $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('Red', 0.25))
                    $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('Blue', 0.75))
                    $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('LimeGreen', 1.0))
                }
            }
        }.InvokeWithContext($null, $psVars) | Out-Null

        $border.Child | Should -BeOfType ([System.Windows.Shapes.Rectangle])
        $border.Child.Width | Should -Be 200
        $border.Child.Height | Should -Be 100
        $border.Child.Fill | Should -BeOfType ([System.Windows.Media.LinearGradientBrush])
        $border.Child.Fill.GradientStops.Count | Should -Be 4
    }

    It 'Should reject keyed LinearGradientBrush usage outside Theme' {
        {
            $rectangle = [System.Windows.Shapes.Rectangle]::new()
            $rectangle.Fill = LinearGradientBrush 'NotAThemeKey' {
                $this.StartPoint = '0,0'
                $this.EndPoint = '1,1'
            } -ErrorAction Stop
        } | Should -Throw
    }
}
