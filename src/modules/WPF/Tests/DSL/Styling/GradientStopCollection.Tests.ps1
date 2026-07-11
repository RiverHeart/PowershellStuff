Describe 'GradientStopCollection' -Tag 'GradientStopCollection' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should create a GradientStopCollection from a scriptblock' {
        $collection = GradientStopCollection {
            GradientStop 'WhiteSmoke' 0.2
            GradientStop 'Transparent' 0.4
            GradientStop 'WhiteSmoke' 0.5
        }

        ($collection -is [System.Windows.Media.GradientStopCollection]) | Should -BeTrue
        $collection.Count | Should -Be 3
    }

    It 'Should assign a GradientStopCollection to a LinearGradientBrush' {
        $glassStops = GradientStopCollection {
            GradientStop 'WhiteSmoke' 0.2
            GradientStop 'Transparent' 0.4
        }

        $brush = LinearGradientBrush {
            $this.StartPoint = '0,0'
            $this.EndPoint = '1,1'
            $this.GradientStops = $glassStops
        }

        $brush | Should -BeOfType ([System.Windows.Media.LinearGradientBrush])
        $brush.GradientStops.Count | Should -Be 2
        $brush.GradientStops[0].Color.ToString() | Should -Be '#FFF5F5F5'
        $brush.GradientStops[1].Color.ToString() | Should -Be '#00FFFFFF'
    }

    It 'Should require a key when used inside Theme' {
        $id = [guid]::NewGuid().ToString('N')
        $themeName = "GradientStopsMissingKey_$id"

        {
            Theme $themeName {
                GradientStopCollection {
                    GradientStop 'WhiteSmoke' 0.2
                }
            } -ErrorAction Stop
        } | Should -Throw
    }
}
