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

Style 'PrimaryButton' Button {
    Setter Background '#0A84FF'
    Setter Foreground '#FFFFFF'
    Setter BorderBrush '#086FD5'

    Template {
        Border 'ButtonChrome' {
            Setter Background '#0A84FF'
            Setter BorderBrush '#086FD5'
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
            Setter Background '#0978E6' -Target 'ButtonChrome'
            Setter BorderBrush '#075FBA' -Target 'ButtonChrome'
        }

        Trigger IsPressed $true {
            Setter Background '#0869C9' -Target 'ButtonChrome'
            Setter BorderBrush '#064F97' -Target 'ButtonChrome'
        }

        Trigger IsKeyboardFocused $true {
            Setter BorderBrush '#1D4ED8' -Target 'ButtonChrome'
        }

        Trigger IsEnabled $false {
            Setter Background '#B6D7FF' -Target 'ButtonChrome'
            Setter BorderBrush '#9FC5EF' -Target 'ButtonChrome'
            Setter Foreground '#E8F2FF'
        }
    }
}

Style 'DangerButton' Button {
    Setter Background '#DC2626'
    Setter Foreground '#FFFFFF'
    Setter BorderBrush '#B91C1C'

    Template {
        Border 'ButtonChrome' {
            Setter Background '#DC2626'
            Setter BorderBrush '#B91C1C'
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
            Setter Background '#C91F1F' -Target 'ButtonChrome'
            Setter BorderBrush '#A31515' -Target 'ButtonChrome'
        }

        Trigger IsPressed $true {
            Setter Background '#B31B1B' -Target 'ButtonChrome'
            Setter BorderBrush '#8F1212' -Target 'ButtonChrome'
        }

        Trigger IsKeyboardFocused $true {
            Setter BorderBrush '#991B1B' -Target 'ButtonChrome'
        }

        Trigger IsEnabled $false {
            Setter Background '#F3B0B0' -Target 'ButtonChrome'
            Setter BorderBrush '#E39A9A' -Target 'ButtonChrome'
            Setter Foreground '#FFF4F4'
        }
    }
}

Style 'GhostButton' Button {
    Setter Background '#FFFFFF'
    Setter Foreground '#1F2937'
    Setter BorderBrush '#B8C0CC'

    Template {
        Border 'ButtonChrome' {
            Setter Background '#FFFFFF'
            Setter BorderBrush '#B8C0CC'
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
            Setter Background '#F8FAFC' -Target 'ButtonChrome'
            Setter BorderBrush '#9EA8B8' -Target 'ButtonChrome'
        }

        Trigger IsPressed $true {
            Setter Background '#F1F5F9' -Target 'ButtonChrome'
            Setter BorderBrush '#8B97AA' -Target 'ButtonChrome'
        }

        Trigger IsKeyboardFocused $true {
            Setter BorderBrush '#2563EB' -Target 'ButtonChrome'
        }

        Trigger IsEnabled $false {
            Setter Background '#F8FAFC' -Target 'ButtonChrome'
            Setter BorderBrush '#D2D9E3' -Target 'ButtonChrome'
            Setter Foreground '#A1AAB7'
        }
    }
}

Style TextBox {
    Setter BorderBrush '#B8C0CC'
    Setter BorderThickness 1
    Setter Padding 12, 16
    Setter Margin 0, 0, 0, 8
    Setter FontSize 16
    Setter Foreground '#111827'
    Setter Background '#FFFFFF'
    Setter FocusVisualStyle $null

    Border {
        Setter CornerRadius 6
    }

    Trigger IsMouseOver $true {
        Setter BorderBrush '#9EA8B8'
    }

    Trigger IsKeyboardFocused $true {
        Setter BorderBrush '#2563EB'
    }

    Trigger IsEnabled $false {
        Setter Background '#F3F4F6'
        Setter BorderBrush '#D2D9E3'
        Setter Foreground '#A1AAB7'
    }
}
