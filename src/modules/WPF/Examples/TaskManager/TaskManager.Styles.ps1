<#
.SYNOPSIS
    Style declarations for the TaskManager project.

.DESCRIPTION
    Add theme, brush, and style definitions in this file as your project grows.
#>

# Right-aligned DataGrid header style for CPU/Memory columns
Style 'RightAlignedDataGridHeader' DataGridColumnHeader {
    Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
    Setter HorizontalContentAlignment ([HorizontalAlignment]::Right)
}

# Right-aligned DataGrid cell style for CPU/Memory columns
Style 'RightAlignedDataGridCell' TextBlock {
    Setter HorizontalAlignment ([HorizontalAlignment]::Right)
}

# DataGrid header and cell alignment styles
Style DataGridColumnHeader {
    Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
    Setter HorizontalContentAlignment ([HorizontalAlignment]::Right)
}

Style TextBlock {
    Setter HorizontalAlignment ([HorizontalAlignment]::Right)
}

# Windows-native style button for bottom-bar actions
Style 'TaskManager.NativeButton' Button {
    Setter Background '#F8FAFC'
    Setter Foreground '#111827'
    Setter BorderBrush '#8E9AAF'
    Setter BorderThickness 2
    Setter Padding '14,8,14,8'
    Setter Margin '0,10,10,10'
    Setter FontSize 16
    Setter MinWidth 124
    Setter Cursor ([System.Windows.Input.Cursors]::Hand)
    Setter FocusVisualStyle $null
    Setter SnapsToDevicePixels $true
    Setter OverridesDefaultStyle $true

    Template {
        Border 'ButtonChrome' {
            Setter Background '#F8FAFC'
            Setter BorderBrush '#8E9AAF'
            Setter BorderThickness 2
            Setter CornerRadius 6
            Setter SnapsToDevicePixels $true

            ContentPresenter {
                Setter Margin '14,8,14,8'
                Setter HorizontalAlignment ([HorizontalAlignment]::Center)
                Setter VerticalAlignment ([VerticalAlignment]::Center)
                Setter RecognizesAccessKey $true
            }
        }

        Trigger IsMouseOver $true {
            Setter Background '#E9EEF7' -Target 'ButtonChrome'
            Setter BorderBrush '#7D8BA3' -Target 'ButtonChrome'
        }

        Trigger IsPressed $true {
            Setter Background '#DDE6F3' -Target 'ButtonChrome'
            Setter BorderBrush '#6D7D98' -Target 'ButtonChrome'
        }

        Trigger IsKeyboardFocused $true {
            Setter BorderBrush '#2563EB' -Target 'ButtonChrome'
        }

        Trigger IsEnabled $false {
            Setter Background '#F3F4F6' -Target 'ButtonChrome'
            Setter BorderBrush '#D6DCE5' -Target 'ButtonChrome'
            Setter Foreground '#9CA3AF'
        }
    }
}
