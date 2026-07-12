using namespace System.Windows
using namespace System.Windows.Media.Effects

Resources {
    LinearGradientBrush 'GrayBlueGradientBrush' {
        $this.StartPoint = '0,0'
        $this.EndPoint = '1,1'
        GradientStop 'DarkGray' 0
        GradientStop '#CCCCFF' 0.5
        GradientStop 'DarkGray' 1
    }

    LinearGradientBrush 'GlassGradientBrush' {
        $this.StartPoint = '0,0'
        $this.EndPoint = '1,1'
        $this.Opacity = 0.75
        $this.GradientStops = GradientStopCollection {
            GradientStop WhiteSmoke 0.2
            GradientStop Transparent 0.4
            GradientStop WhiteSmoke 0.5
            GradientStop Transparent 0.75
            GradientStop WhiteSmoke 0.9
            GradientStop Transparent 1.0
        }
    }

    Style Window {
        Background: Black
    }

    Style Button {
        Width: 90
        Margin: 10
        Background: GrayBlueGradientBrush -Resource

        Template {
            Trigger IsMouseOver $true {
                # Change the color of the outer rectangle when user mouses over it.
                Setter `
                    -Property 'Rectangle.Stroke' `
                    -Target OuterRect `
                    -Value ([SystemColors]::HighlightBrushKey) `
                    -Resource

                # Sets the glass opacity to 1, therefore, the glass "appears" when user mouses over it.
                Setter -Property 'Rectangle.Opacity' -Target 'GlassCube' -Value 1

                # Makes the text slightly blurry as though you were looking at it through blurry glass.
                $BlurEffect = [BlurBitmapEffect]::new()
                $BlurEffect.Radius = 1
                Setter -Property 'ContentPresenter.BitmapEffect' -Target 'ContentPresenter' -Value $BlurEffect
            }

            Trigger IsFocused $true {
                # Sets the glass opacity to 1, therefore, the glass "appears" when the button is focused.
                Setter -Property 'Rectangle.Opacity' -Target 'GlassCube' -Value 1

                # Change the color of the outer rectangle when the button is focused.
                Setter -Property 'Rectangle.Stroke' -Target 'OuterRect' -Value ([SystemColors]::HighlightBrushKey) -Resource
            }

            Grid {
                Width: (TemplateBinding Width)
                Height: (TemplateBinding Height)
                ClipToBounds: $true

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
                    Fill: GlassGradientBrush -Resource
                    StrokeThickness: 2
                    RadiusX: 10
                    RadiusY: 10
                    Opacity: 1
                    RenderTransformOrigin: '0.5,0.5'
                    Stroke: (LinearGradientBrush {
                        $this.StartPoint = '0.5,0'
                        $this.EndPoint = '0.5,1'
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
}
