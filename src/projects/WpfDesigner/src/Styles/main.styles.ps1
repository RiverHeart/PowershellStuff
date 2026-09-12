Resources {
    # Scoped to the enclosing Window so it only affects controls on the design surface.
    Style Label {
        BorderBrush: '#999999'
        BorderThickness: 1
        Padding: 4

        Trigger IsMouseOver $true {
            BorderBrush: '#2563EB'
            Background: '#EFF6FF'
        }
    }

    # Flattens the resize handle: the default Thumb chrome has an OS-themed
    # bevel/gradient that's hard to make out at this control's small size.
    Style Thumb {
        Template {
            Border 'ThumbBorder' {
                Background: (TemplateBinding Background)
                BorderBrush: (TemplateBinding BorderBrush)
                BorderThickness: (TemplateBinding BorderThickness)
            }
        }
    }
}
