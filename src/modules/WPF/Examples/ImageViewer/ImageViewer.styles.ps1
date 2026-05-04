Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
    Brush 'SurfaceBackground' '#F8F8F8'
    Brush 'Foreground' '#111111'
    Brush 'DisabledForeground' '#7A7A7A'
    Brush 'ScrollBackground' '#1A1A1A'
    Brush 'ButtonBackground' '#EDEDED'
    Brush 'ButtonHoverBackground' '#D0D0D0'
}

Theme 'Dark' {
    Brush 'WindowBackground' '#1E1E1E'
    Brush 'SurfaceBackground' '#111111'
    Brush 'Foreground' '#F0F0F0'
    Brush 'DisabledForeground' '#8F8F8F'
    Brush 'ScrollBackground' '#050505'
    Brush 'ButtonBackground' '#2A2A2A'
    Brush 'ButtonHoverBackground' '#3E3E3E'
}

Style Window {
    Setter Background WindowBackground -Resource
    Setter Foreground Foreground -Resource
}

Style Button {
    Setter Background ButtonBackground -Resource
    Setter Foreground Foreground -Resource
}

Style 'ImageViewer.IconButton' Button {
    Setter Background 'Transparent'
    Setter BorderBrush 'Transparent'
    Setter BorderThickness 0
    Setter Padding 0
    Setter FocusVisualStyle $null
    Setter HorizontalContentAlignment ([HorizontalAlignment]::Stretch)
    Setter VerticalContentAlignment ([VerticalAlignment]::Stretch)
    Setter OverridesDefaultStyle $true

    # Icon sizing: the icon occupies $IconScale of the button's interior.
    # Padding fills the remaining space equally on all sides.
    $ButtonSize = 56
    $IconScale = 0.6
    $IconPadding = [int](($ButtonSize * (1 - $IconScale)) / 2)
    $CornerRadius = 8
    $IconButtonMargin = 5

    Setter Width $ButtonSize
    Setter Height $ButtonSize
    Setter Margin $IconButtonMargin

    Template {
        Border 'TemplateBorder' {
            Setter CornerRadius $CornerRadius
            Setter Padding $IconPadding
            Setter BorderThickness 1
            Setter Background ButtonBackground -Resource
            Setter BorderBrush DisabledForeground -Resource

            ContentPresenter {
                Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
                Setter VerticalAlignment ([VerticalAlignment]::Stretch)
                Setter SnapsToDevicePixels $true
            }
        }

        # Hover trigger — highlights TemplateBorder when the pointer is over the button.
        Trigger IsMouseOver $true {
            Setter Background ButtonHoverBackground -Resource -Target 'TemplateBorder'
        }
    }
}

Style 'ImageViewer.IconPath' Path {
    Setter Stretch ([System.Windows.Media.Stretch]::Uniform)
    Setter StrokeThickness 0
    Setter Fill Foreground -Resource
    Setter Stroke Foreground -Resource
}

Style ScrollViewer {
    Setter Background ScrollBackground -Resource
}

Style Menu {
    Setter Background WindowBackground -Resource
    Setter Foreground Foreground -Resource
}

Style MenuItem {
    Setter Background WindowBackground -Resource
    Setter Foreground Foreground -Resource
}

Style Label {
    Setter Background 'Transparent'
    Setter Foreground Foreground -Resource
}
