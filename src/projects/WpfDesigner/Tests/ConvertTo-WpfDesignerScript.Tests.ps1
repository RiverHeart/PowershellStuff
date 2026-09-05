Describe 'ConvertTo-WpfDesignerScript' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/ConvertTo-WpfDesignerScript.ps1"
    }

    It 'Should emit a Window/Canvas block with no Labels' {
        $Canvas = [System.Windows.Controls.Canvas]::new()

        $Script = ConvertTo-WpfDesignerScript -Canvas $Canvas

        $Script | Should -Match "Window 'Window' \{"
        $Script | Should -Match "Canvas 'Canvas' \{"
    }

    It 'Should emit a Label block with content, size, and position' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Label = [System.Windows.Controls.Label]::new()
        $Label.Content = 'Hello'
        $Label.Width = 100
        $Label.Height = 26
        [System.Windows.Controls.Canvas]::SetLeft($Label, 20)
        [System.Windows.Controls.Canvas]::SetTop($Label, 44)
        $Canvas.Children.Add($Label) | Out-Null

        $Script = ConvertTo-WpfDesignerScript -Canvas $Canvas

        $Script | Should -Match "\`$this\.Content = 'Hello'"
        $Script | Should -Match "\`$this\.Width = 100"
        $Script | Should -Match "\`$this\.Height = 26"
        $Script | Should -Match 'CanvasPosition -Left 20 -Top 44'
    }

    It 'Should escape single quotes in Label content' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Label = [System.Windows.Controls.Label]::new()
        $Label.Content = "It's a label"
        $Label.Width = 100
        $Label.Height = 26
        $Canvas.Children.Add($Label) | Out-Null

        $Script = ConvertTo-WpfDesignerScript -Canvas $Canvas

        $Script | Should -Match "It''s a label"
    }

    It 'Should skip non-Label children such as a resize handle Thumb' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Label = [System.Windows.Controls.Label]::new()
        $Label.Content = 'Kept'
        $Label.Width = 100
        $Label.Height = 26
        $Canvas.Children.Add($Label) | Out-Null
        $Canvas.Children.Add([System.Windows.Controls.Primitives.Thumb]::new()) | Out-Null

        $Script = ConvertTo-WpfDesignerScript -Canvas $Canvas

        ([regex]::Matches($Script, 'Label \{')).Count | Should -Be -ExpectedValue 1
    }

    It 'Should default position to 0 when Canvas.Left/Top are unset' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Label = [System.Windows.Controls.Label]::new()
        $Label.Content = 'NoPosition'
        $Label.Width = 100
        $Label.Height = 26
        $Canvas.Children.Add($Label) | Out-Null

        $Script = ConvertTo-WpfDesignerScript -Canvas $Canvas

        $Script | Should -Match 'CanvasPosition -Left 0 -Top 0'
    }
}
