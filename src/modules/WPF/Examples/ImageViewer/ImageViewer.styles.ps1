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
