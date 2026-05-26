using namespace System.Windows.Media

Theme 'Light' {
    WindowBackground: '#FFFFFF'
    SurfaceBackground: '#F8F8F8'
    Foreground: '#111111'
    DisabledForeground: '#7A7A7A'
    ScrollBackground: '#1A1A1A'
    ButtonBackground: '#EDEDED'
    ButtonHoverBackground: '#D0D0D0'
}

Theme 'Dark' {
    WindowBackground: '#1E1E1E'
    SurfaceBackground: '#111111'
    Foreground: '#F0F0F0'
    DisabledForeground: '#8F8F8F'
    ScrollBackground: '#050505'
    ButtonBackground: '#2A2A2A'
    ButtonHoverBackground: '#3E3E3E'
}

Style Window {
    Background: WindowBackground -Resource
    Foreground: Foreground -Resource
}

Style Button {
    Background: ButtonBackground -Resource
    Foreground: Foreground -Resource
}

Style 'ImageViewer.IconButton' Button {
    Background: 'Transparent'
    BorderBrush: 'Transparent'
    BorderThickness: 0
    Padding: 0
    FocusVisualStyle: $null
    HorizontalContentAlignment: ([HorizontalAlignment]::Stretch)
    VerticalContentAlignment: ([VerticalAlignment]::Stretch)
    OverridesDefaultStyle: $true

    # Icon sizing: the icon occupies $IconScale of the button's interior.
    # Padding fills the remaining space equally on all sides.
    $ButtonSize = 56
    $IconScale = 0.6
    $IconPadding = [int](($ButtonSize * (1 - $IconScale)) / 2)
    $CornerRadius = 8
    $IconButtonMargin = 5

    Width: $ButtonSize
    Height: $ButtonSize
    Margin: $IconButtonMargin

    Template {
        Border 'TemplateBorder' {
            CornerRadius: $CornerRadius
            Padding: $IconPadding
            BorderThickness: 1
            Background: ButtonBackground -Resource
            BorderBrush: DisabledForeground: -Resource

            ContentPresenter {
                HorizontalAlignment: ([HorizontalAlignment]::Stretch)
                VerticalAlignment: ([VerticalAlignment]::Stretch)
                SnapsToDevicePixels: $true
            }
        }

        # Hover trigger — highlights TemplateBorder when the pointer is over the button.
        Trigger IsMouseOver $true {
            Background: ButtonHoverBackground -Resource -Target 'TemplateBorder'
        }
    }
}

Style 'ImageViewer.IconPath' Path {
    Stretch: ([Stretch]::Uniform)
    StrokeThickness: 0
    Fill: DisabledForeground -Resource
    Stroke: DisabledForeground -Resource

    Trigger IsEnabled $true {
        Fill: Foreground -Resource
        Stroke: Foreground -Resource
    }
}

Style ScrollViewer {
    Background: ScrollBackground -Resource
}

Style Menu {
    Background: WindowBackground -Resource
    Foreground: Foreground -Resource
}

Style 'ImageViewer.UnthemedMenuItem' MenuItem {
    # Use OS system brushes so MenuItem stays unthemed and does not inherit Menu foreground.
    Background: ([System.Windows.SystemColors]::MenuBrush)
    Foreground: ([System.Windows.SystemColors]::MenuTextBrush)
}

Style Label {
    Background: 'Transparent'
    Foreground: Foreground -Resource
}
