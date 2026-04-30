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

    $Template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])

    # Icon sizing: the icon occupies $IconScale of the button's interior.
    # Padding fills the remaining space equally on all sides.
    $ButtonSize    = 56
    $IconScale     = 0.6
    $IconPadding   = [int](($ButtonSize * (1 - $IconScale)) / 2)
    $CornerRadius  = 8

    $BorderFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Border])
    $BorderFactory.Name = 'TemplateBorder'
    $BorderFactory.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, [System.Windows.CornerRadius]::new($CornerRadius))
    $BorderFactory.SetValue([System.Windows.Controls.Border]::PaddingProperty, [System.Windows.Thickness]::new($IconPadding))
    $BorderFactory.SetValue([System.Windows.Controls.Border]::BorderThicknessProperty, [System.Windows.Thickness]::new(1))
    $BorderFactory.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'ButtonBackground')
    $BorderFactory.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'DisabledForeground')

    $Presenter = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.ContentPresenter])
    $Presenter.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [HorizontalAlignment]::Stretch)
    $Presenter.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [VerticalAlignment]::Stretch)
    $Presenter.SetValue([System.Windows.Controls.ContentPresenter]::SnapsToDevicePixelsProperty, $true)

    $BorderFactory.AppendChild($Presenter)
    $Template.VisualTree = $BorderFactory

    # Hover trigger — highlights TemplateBorder when the pointer is over the button.
    $HoverTrigger = [System.Windows.Trigger]::new()
    $HoverTrigger.Property = [System.Windows.UIElement]::IsMouseOverProperty
    $HoverTrigger.Value = $true
    $HoverSetter = [System.Windows.Setter]::new(
        [System.Windows.Controls.Border]::BackgroundProperty,
        [System.Windows.DynamicResourceExtension]::new('ButtonHoverBackground')
    )
    $HoverSetter.TargetName = 'TemplateBorder'
    $HoverTrigger.Setters.Add($HoverSetter) | Out-Null
    $Template.Triggers.Add($HoverTrigger) | Out-Null

    $this.Setters.Add(
        [System.Windows.Setter]::new([System.Windows.Controls.Control]::TemplateProperty, $Template)
    ) | Out-Null
}

Style 'ImageViewer.IconPath' Path {
    Setter Stretch ([Stretch]::Uniform)
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
