$GrayBlueGradientBrush = LinearGradientBrush {
    $this.StartPoint = '0,0'
    $this.EndPoint = '1,1'
    GradientStop 'DarkGray' 0
    GradientStop '#CCCCFF' 0.5
    GradientStop 'DarkGray' 1
}

Style Button {
    Width: 80
    Margin: 10
    Background: $GrayBlueGradientBrush

    Template {
        Grid {
            Width: (TemplateBinding Width)
            Height: (TemplateBinding Height)
            # Outer Rectangle with rounded corners
            Rectangle 'OuterRect' {
                HorizontalAlignment: ([HorizontalAlignment]::Stretch)
                VerticalAlignment: ([VerticalAlignment]::Stretch)
                RadiusX: 20
                RadiusY: 20
                Fill: 'Transparent'
                Stroke: (TemplateBinding Background)
                StrokeThickness: 5
            }
            Rectangle 'InnerRect' {
                RadiusX: 20
                RadiusY: 20
                Fill: (TemplateBinding Background)
                Stroke: 'Transparent'
                StrokeThickness: 20
            }
            DockPanel 'ContentPresenterPanel' {
                ContentPresenter 'ContentPresenter' {
                    Margin: 20
                    Content: (TemplateBinding Content)
                }
            }
        }
    }
}
