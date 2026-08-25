Style Button {
    Background: '#FFFFFF'
    Foreground: '#202124'
    BorderBrush: '#B7BCC5'
    BorderThickness: 1
    Padding: 16, 9
    Margin: 0, 8, 0, 0
    FontSize: 14
    MinHeight: 40
    Cursor: ([System.Windows.Input.Cursors]::Hand)
}

Style 'PrimaryButton' Button {
    ExtendStyle Button
    Background: '#D63B32'
    Foreground: '#FFFFFF'
    BorderBrush: '#B92D27'
}

Style 'GhostButton' Button {
    ExtendStyle Button
    Background: '#FFFFFF'
    Foreground: '#4A4F57'
}

Style 'PokeBrowser.Window' Window {
    Width: 960
    Height: 640
    MinWidth: 760
    MinHeight: 520
    Background: '#F3F4F6'
}

Style 'PokeBrowser.Panel' Border {
    Background: '#FFFFFF'
    BorderBrush: '#D9DCE2'
    BorderThickness: 1
    CornerRadius: 8
    Padding: 24
    Width: 600
}

Style 'PokeBrowser.CatalogPanel' Border {
    ExtendStyle 'PokeBrowser.Panel'
    Width: 300
    Margin: 0, 0, 20, 0
}

Style 'PokeBrowser.ImageFrame' Border {
    Background: '#FFF4C2'
    BorderBrush: '#E4C85A'
    BorderThickness: 1
    CornerRadius: 8
    Width: 240
    Height: 240
    Margin: 0, 20, 28, 0
}

Style 'PokeBrowser.Title' TextBlock {
    FontFamily: 'Segoe UI Semibold'
    FontSize: 30
    Foreground: '#202124'
}

Style 'PokeBrowser.Status' TextBlock {
    FontSize: 13
    Foreground: '#68707C'
    Margin: 0, 4, 0, 0
}

Style 'PokeBrowser.SectionHeading' TextBlock {
    FontFamily: 'Segoe UI Semibold'
    FontSize: 18
    Foreground: '#202124'
}

Style 'PokeBrowser.PokemonName' TextBlock {
    FontFamily: 'Segoe UI Semibold'
    FontSize: 34
    Foreground: '#202124'
}

Style 'PokeBrowser.FactLabel' TextBlock {
    FontFamily: 'Segoe UI Semibold'
    FontSize: 11
    Foreground: '#68707C'
    Margin: 0, 0, 0, 2
}

Style 'PokeBrowser.FactValue' TextBlock {
    FontSize: 18
    Foreground: '#202124'
    Margin: 0, 0, 0, 18
}

Style 'PokeBrowser.PokemonPicker' ComboBox {
    FontSize: 14
    Foreground: '#202124'
    Background: '#FFFFFF'
    BorderBrush: '#B7BCC5'
    BorderThickness: 1
    Padding: 8, 4
    Margin: 0, 12, 0, 8
    MinHeight: 40
}
