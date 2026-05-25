function New-WPFButtonChromeAdapter {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    return [pscustomobject] @{
        Name = 'Button'
        TargetType = [System.Windows.Controls.Button]
        ShellType = [System.Windows.Controls.Border]
        PartName = 'ButtonChrome'
        ShellPropertyMap = [ordered] @{
            Background = [System.Windows.Controls.Border]::BackgroundProperty
            BorderBrush = [System.Windows.Controls.Border]::BorderBrushProperty
            BorderThickness = [System.Windows.Controls.Border]::BorderThicknessProperty
            SnapsToDevicePixels = [System.Windows.UIElement]::SnapsToDevicePixelsProperty
        }
        ContentPropertyMap = [ordered] @{
            Padding = [System.Windows.FrameworkElement]::MarginProperty
            HorizontalContentAlignment = [System.Windows.FrameworkElement]::HorizontalAlignmentProperty
            VerticalContentAlignment = [System.Windows.FrameworkElement]::VerticalAlignmentProperty
        }
        ContentDefaults = [ordered] @{
            HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
            VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
        }
    }
}
