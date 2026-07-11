$GrayBlueGradientBrush = LinearGradientBrush {
    $this.StartPoint = '0,0'
    $this.EndPoint = '1,1'
    GradientStop 'DarkGray' 0
    GradientStop '#CCCCFF' 0.5
    GradientStop 'DarkGray' 1
}

$GradientStopCollection =
$LinearGradientBrush = LinearGradientBrush {
    $this.StartPoint = '0,0'
    $this.EndPoint = '1,1'
    $this.GradientStops = GradientStopCollection {
        GradientStop WhiteSmoke 0.2
        GradientStop Transparent 0.4
        GradientStop WhiteSmoke 0.5
        GradientStop Transparent 0.75
        GradientStop WhiteSmoke 0.9
        GradientStop Transparent 1.0
    }
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
            # Inner Rectangle with rounded corners
            Rectangle 'InnerRect' {
                RadiusX: 20
                RadiusY: 20
                Fill: (TemplateBinding Background)
                Stroke: 'Transparent'
                StrokeThickness: 20
            }
            # Glass Rectangle
            Rectangle 'GlassCube' {
                HorizontalAlignment: ([HorizontalAlignment]::Stretch)
                VerticalAlignment: ([VerticalAlignment]::Stretch)
                Fill: (TemplateBinding Background)
                StrokeThickness: 2
                RadiusX: 10
                RadiusY: 10
                Opacity: 0
                RenderTransformOrigin: '0.5,0.5'
                Stroke: (LinearGradientBrush {
                    $this.StartPoint = '0,0'
                    $this.EndPoint = '1,1'
                    $this.GradientStops = GradientStopCollection {
                        GradientStop LightBlue 0.0
                        GradientStop Gray 1.0
                    }
                })
                BitmapEffect: ([System.Windows.Media.Effects.BevelBitmapEffect]::new())
            }
            DockPanel 'ContentPresenterPanel' {
                ContentPresenter 'ContentPresenter' {
                    Margin: 20
                    Content: (TemplateBinding Content)
                    Textblock.Foreground: 'Black'
                }
            }
        }
    }
}
