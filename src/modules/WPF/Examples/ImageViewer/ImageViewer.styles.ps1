Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
    Brush 'SurfaceBackground' '#F8F8F8'
    Brush 'Foreground' '#111111'
    Brush 'DisabledForeground' '#7A7A7A'
    Brush 'ScrollBackground' '#1A1A1A'
    Brush 'ButtonBackground' '#EDEDED'
}

Theme 'Dark' {
    Brush 'WindowBackground' '#1E1E1E'
    Brush 'SurfaceBackground' '#111111'
    Brush 'Foreground' '#F0F0F0'
    Brush 'DisabledForeground' '#8F8F8F'
    Brush 'ScrollBackground' '#050505'
    Brush 'ButtonBackground' '#2A2A2A'
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

    $Template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])
    $Presenter = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.ContentPresenter])

    $Presenter.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [HorizontalAlignment]::Stretch)
    $Presenter.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [VerticalAlignment]::Stretch)
    $Presenter.SetValue([System.Windows.Controls.ContentPresenter]::SnapsToDevicePixelsProperty, $true)

    $Template.VisualTree = $Presenter

    $this.Setters.Add(
        [System.Windows.Setter]::new([System.Windows.Controls.Control]::TemplateProperty, $Template)
    ) | Out-Null
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
