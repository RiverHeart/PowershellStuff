<#
.SYNOPSIS
    Style declarations for the StarterProject project.

.DESCRIPTION
    Add theme, brush, and style definitions in this file as your project grows.
#>

# Native-ish default button style for new projects.
# Use this implicit style for standard actions, or apply one of the named styles below:
#   UseStyle 'PrimaryButton'
#   UseStyle 'DangerButton'
#   UseStyle 'GhostButton'
Style Button {
    Background: '#F8FAFC'
    Foreground: '#111827'
    BorderBrush: '#8E9AAF'
    BorderThickness: 2
    Padding: 14, 8, 14, 8
    Margin: 0, 8, 0, 0
    FontSize: 14
    MinWidth: 110
    Cursor: ([System.Windows.Input.Cursors]::Hand)
    FocusVisualStyle: $null
    SnapsToDevicePixels: $true
    OverridesDefaultStyle: $true

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#E9EEF7'
        BorderBrush: '#7D8BA3'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#DDE6F3'
        BorderBrush: '#6D7D98'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#2563EB'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#F3F4F6'
        BorderBrush: '#D6DCE5'
    }

    Trigger IsEnabled $false {
        Foreground: '#9CA3AF'
    }
}

Style 'PrimaryButton' Button {
    ExtendStyle Button
    Background: '#0A84FF'
    Foreground: '#FFFFFF'
    BorderBrush: '#086FD5'

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#0978E6'
        BorderBrush: '#075FBA'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#0869C9'
        BorderBrush: '#064F97'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#1D4ED8'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#B6D7FF'
        BorderBrush: '#9FC5EF'
    }

    Trigger IsEnabled $false {
        Foreground: '#E8F2FF'
    }
}

Style 'DangerButton' Button {
    ExtendStyle Button
    Background: '#DC2626'
    Foreground: '#FFFFFF'
    BorderBrush: '#B91C1C'

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#C91F1F'
        BorderBrush: '#A31515'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#B31B1B'
        BorderBrush: '#8F1212'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#991B1B'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#F3B0B0'
        BorderBrush: '#E39A9A'
    }

    Trigger IsEnabled $false {
        Foreground: '#FFF4F4'
    }
}

Style 'GhostButton' Button {
    ExtendStyle Button
    Background: '#FFFFFF'
    Foreground: '#1F2937'
    BorderBrush: '#B8C0CC'

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#F8FAFC'
        BorderBrush: '#9EA8B8'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#F1F5F9'
        BorderBrush: '#8B97AA'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#2563EB'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#F8FAFC'
        BorderBrush: '#D2D9E3'
    }

    Trigger IsEnabled $false {
        Foreground: '#A1AAB7'
    }
}

Style TextBox {
    BorderBrush: '#B8C0CC'
    BorderThickness: 1
    Padding: 10, 8
    Margin: 0, 0, 0, 8
    MinHeight: 38
    FontSize: 16
    Foreground: '#111827'
    Background: '#FFFFFF'
    FocusVisualStyle: $null

    Template {
        Border 'InputChrome' {
            CornerRadius: 6
            Background: '#FFFFFF'
            BorderBrush: '#B8C0CC'
            BorderThickness: 1
            SnapsToDevicePixels: $true

            ScrollViewer 'PART_ContentHost' {
                Margin: 10, 8, 10, 8
                Focusable: $false
                HorizontalAlignment: ([HorizontalAlignment]::Stretch)
                VerticalAlignment: ([VerticalAlignment]::Stretch)
            }
        }

        Trigger IsMouseOver $true {
            BorderBrush: '#9EA8B8' -Target 'InputChrome'
        }

        Trigger IsKeyboardFocused $true {
            BorderBrush: '#2563EB' -Target 'InputChrome'
        }

        Trigger IsEnabled $false {
            Background: '#F3F4F6' -Target 'InputChrome'
            BorderBrush: '#D2D9E3' -Target 'InputChrome'
            Foreground: '#A1AAB7'
        }
    }
}
