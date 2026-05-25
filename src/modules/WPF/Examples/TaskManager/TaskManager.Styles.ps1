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

# Chrome-based style used by StopProcessButton in TaskManager.DSL.ps1
Style 'TaskManager.StopButton' Button {
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

    Chrome {
        Setter CornerRadius 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Setter Background '#E9EEF7'
        Setter BorderBrush '#7D8BA3'
    }

    Trigger IsPressed $true -Scope Chrome {
        Setter Background '#DDE6F3'
        Setter BorderBrush '#6D7D98'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        Setter BorderBrush '#2563EB'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Setter Background '#F3F4F6'
        Setter BorderBrush '#D6DCE5'
    }

    Trigger IsEnabled $false {
        Setter Foreground '#9CA3AF'
    }
}
