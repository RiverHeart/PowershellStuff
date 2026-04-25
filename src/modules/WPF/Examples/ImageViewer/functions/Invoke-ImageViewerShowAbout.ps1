function Invoke-ImageViewerShowAbout {
    [CmdletBinding()]
    param()

    $ParentWindow = Reference 'Window'

    Window 'About_Window' {
        $this.Title = 'About Image Viewer'
        $this.WindowStartupLocation = [WindowStartupLocation]::CenterOwner
        $this.Owner = $ParentWindow
        $this.Height = 250
        $this.Width = 400
        $this.ResizeMode = [ResizeMode]::NoResize
        $this.TopMost = $true

        Use-WPFTheme -Name $ParentWindow.Tag.CurrentTheme -Root $this

        StackPanel 'About_MainStackPanel' {
            $this.Margin = 20
            $this.VerticalAlignment = [VerticalAlignment]::Center

            Label 'About_TitleLabel' {
                $this.FontSize = 22
                $this.FontWeight = [FontWeights]::Bold
                $this.Content = 'Image Viewer'
                $this.Margin = 0, 0, 0, 10
            }
            Label 'About_DescriptionTextBlock' {
                $this.FontSize = 14
                $this.Margin = 0, 0, 0, 10

                TextBlock 'About_DescriptionText' {
                    $this.FontSize = 14
                    $this.TextWrapping = [TextWrapping]::Wrap
                    $this.Text = 'A simple yet powerful image viewer for browsing and navigating through image files.'
                }
            }
            Label 'About_FeaturesHeaderLabel' {
                $this.FontSize = 12
                $this.Content = 'Features:'
                $this.FontWeight = [FontWeights]::Bold
                $this.Margin = 0, 0, 0, 5
            }
            TextBlock 'About_FeaturesTextBlock' {
                $this.FontSize = 12
                $this.Margin = 20, 0, 0, 15
                $this.TextWrapping = [TextWrapping]::Wrap
                $this.Text = @"
• Navigate with arrow keys or buttons
• Zoom with Ctrl + Mouse Wheel
• Press F11 to toggle fullscreen
• Drag and drop images to open
• Click buttons to go forward/back
"@
            }
            StackPanel 'About_ButtonPanel' {
                $this.Orientation = [Orientation]::Horizontal
                $this.HorizontalAlignment = [HorizontalAlignment]::Right

                Button 'About_OKButton' {
                    $this.Content = 'OK'
                    $this.FontSize = 12
                    $this.Width = 75
                    $this.Margin = 5

                    When Click {
                        $Window = Reference 'About_Window'
                        $Window.DialogResult = $true
                    }
                }
            }
        }
    } | Show-WPFWindow
}
