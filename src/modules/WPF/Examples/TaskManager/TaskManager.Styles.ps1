<#
.SYNOPSIS
    Style declarations for the TaskManager project.

.DESCRIPTION
    Add theme, brush, and style definitions in this file as your project grows.
#>

# Right-aligned DataGrid header style for CPU/Memory columns
Style 'RightAlignedDataGridHeader' DataGridColumnHeader {
    HorizontalAlignment: ([HorizontalAlignment]::Stretch)
    HorizontalContentAlignment: ([HorizontalAlignment]::Right)
}

# Right-aligned DataGrid cell style for CPU/Memory columns
Style 'RightAlignedDataGridCell' TextBlock {
    HorizontalAlignment: ([HorizontalAlignment]::Right)
}

# DataGrid header and cell alignment styles
Style DataGridColumnHeader {
    HorizontalAlignment: ([HorizontalAlignment]::Stretch)
    HorizontalContentAlignment: ([HorizontalAlignment]::Right)
}

Style TextBlock {
    HorizontalAlignment: ([HorizontalAlignment]::Right)
}

# Chrome-based style used by StopProcessButton in TaskManager.DSL.ps1
Style 'TaskManager.StopButton' Button {
    Background: '#F8FAFC'
    Foreground: '#111827'
    BorderBrush: '#8E9AAF'
    BorderThickness: 2
    Padding: '14,8,14,8'
    Margin: '0,10,10,10'
    FontSize: 16
    MinWidth: 124
    Cursor: ([System.Windows.Input.Cursors]::Hand)
    FocusVisualStyle: $null
    SnapsToDevicePixels: $true

    Chrome {
        CornerRadius: 6

        Trigger IsMouseOver $true {
            Background: '#E9EEF7'
            BorderBrush: '#7D8BA3'
        }

        Trigger IsPressed $true {
            Background: '#DDE6F3'
            BorderBrush: '#6D7D98'
        }

        Trigger IsKeyboardFocused $true {
            BorderBrush: '#2563EB'
        }

        Trigger IsEnabled $false {
            Background: '#F3F4F6'
            BorderBrush: '#D6DCE5'
        }
    }

    Trigger IsEnabled $false {
        Foreground: '#9CA3AF'
    }
}
