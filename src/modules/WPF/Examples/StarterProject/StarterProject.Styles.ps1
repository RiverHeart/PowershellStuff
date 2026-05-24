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
    Setter Background '#F8FAFC'
    Setter Foreground '#111827'
    Setter BorderBrush '#8E9AAF'
    Setter BorderThickness 2
    Setter Padding '14,8,14,8'
    Setter Margin '0,8,0,0'
    Setter FontSize 14
    Setter MinWidth 110
    Setter Cursor ([System.Windows.Input.Cursors]::Hand)
    Setter FocusVisualStyle $null
    Setter SnapsToDevicePixels $true
    Setter OverridesDefaultStyle $true

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

Style 'PrimaryButton' Button {
    ExtendStyle Button
    Setter Background '#0A84FF'
    Setter Foreground '#FFFFFF'
    Setter BorderBrush '#086FD5'

    Chrome {
        Setter CornerRadius 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Setter Background '#0978E6'
        Setter BorderBrush '#075FBA'
    }

    Trigger IsPressed $true -Scope Chrome {
        Setter Background '#0869C9'
        Setter BorderBrush '#064F97'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        Setter BorderBrush '#1D4ED8'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Setter Background '#B6D7FF'
        Setter BorderBrush '#9FC5EF'
    }

    Trigger IsEnabled $false {
        Setter Foreground '#E8F2FF'
    }
}

Style 'DangerButton' Button {
    ExtendStyle Button
    Setter Background '#DC2626'
    Setter Foreground '#FFFFFF'
    Setter BorderBrush '#B91C1C'

    Chrome {
        Setter CornerRadius 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Setter Background '#C91F1F'
        Setter BorderBrush '#A31515'
    }

    Trigger IsPressed $true -Scope Chrome {
        Setter Background '#B31B1B'
        Setter BorderBrush '#8F1212'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        Setter BorderBrush '#991B1B'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Setter Background '#F3B0B0'
        Setter BorderBrush '#E39A9A'
    }

    Trigger IsEnabled $false {
        Setter Foreground '#FFF4F4'
    }
}

Style 'GhostButton' Button {
    ExtendStyle Button
    Setter Background '#FFFFFF'
    Setter Foreground '#1F2937'
    Setter BorderBrush '#B8C0CC'

    Chrome {
        Setter CornerRadius 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Setter Background '#F8FAFC'
        Setter BorderBrush '#9EA8B8'
    }

    Trigger IsPressed $true -Scope Chrome {
        Setter Background '#F1F5F9'
        Setter BorderBrush '#8B97AA'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        Setter BorderBrush '#2563EB'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Setter Background '#F8FAFC'
        Setter BorderBrush '#D2D9E3'
    }

    Trigger IsEnabled $false {
        Setter Foreground '#A1AAB7'
    }
}

Style TextBox {
    Setter BorderBrush '#B8C0CC'
    Setter BorderThickness 1
    Setter Padding 10, 8
    Setter Margin 0, 0, 0, 8
    Setter MinHeight 38
    Setter FontSize 16
    Setter Foreground '#111827'
    Setter Background '#FFFFFF'
    Setter FocusVisualStyle $null

    Template {
        Border 'InputChrome' {
            Setter CornerRadius 6
            Setter Background '#FFFFFF'
            Setter BorderBrush '#B8C0CC'
            Setter BorderThickness 1
            Setter SnapsToDevicePixels $true

            ScrollViewer 'PART_ContentHost' {
                Setter Margin '10,8,10,8'
                Setter Focusable $false
                Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
                Setter VerticalAlignment ([VerticalAlignment]::Stretch)
            }
        }

        Trigger IsMouseOver $true {
            Setter BorderBrush '#9EA8B8' -Target 'InputChrome'
        }

        Trigger IsKeyboardFocused $true {
            Setter BorderBrush '#2563EB' -Target 'InputChrome'
        }

        Trigger IsEnabled $false {
            Setter Background '#F3F4F6' -Target 'InputChrome'
            Setter BorderBrush '#D2D9E3' -Target 'InputChrome'
            Setter Foreground '#A1AAB7'
        }
    }
}
