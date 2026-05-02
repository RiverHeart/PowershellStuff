# WPF Theme and Style DSL Reference

## Purpose

This document summarizes the current WPF DSL support for:

- Theme registration and runtime theme switching
- Reusable styles
- Implicit target-type styles
- Practical usage patterns for examples and apps

## Keywords at a glance

### Theme and resources

- `Theme <Name> { ... }`
  - Registers a named `ResourceDictionary` in module state.
- `Brush <Key> <Color>`
  - Adds a `SolidColorBrush` to the current theme dictionary.
- `Use-WPFTheme -Name <ThemeName> [-Root <FrameworkElement>]`
  - Applies a registered theme to a root element by swapping theme dictionaries.
- `Toggle-WPFTheme [-LightName Light] [-DarkName Dark] [-Root <FrameworkElement>]`
  - Switches between two theme names.
- `Resource <Property> <Key>`
  - Binds a dependency property to a dynamic resource key on the current object.

### Styles

- `Style <Name> <TargetType> { ... }`
  - Defines a **named style** (apply explicitly with `UseStyle`).
- `Style <TargetType> { ... }`
  - Defines an **implicit style** for that target type (auto-applied to controls of that type).
- `Setter <Property> <Value> [-Resource]`
  - Adds a setter to the current style.
  - `-Resource` stores a `DynamicResource` reference.
- `UseStyle <Name> [-InputObject <Object>]`
  - Applies a named style to a target object.

## How dynamic theme updates work

Theme toggling updates live only when styles/properties are bound through dynamic resources.

Use one of these:

- `Setter Background ButtonBackground -Resource`
- `Resource Background ButtonBackground`

Avoid hard-coded brush assignments when you expect runtime theme changes.

## Named vs implicit styles

### Named styles

Use when a style is a specific variant and should be opt-in:

```powershell
Style 'PrimaryButton' Button {
    Setter Background ButtonBackground -Resource
    Setter Foreground Foreground -Resource
}

Button 'SaveButton' {
    UseStyle 'PrimaryButton'
}
```

### Implicit target-type styles

Use when you want all controls of a given type to share defaults:

```powershell
Style Button {
    Setter Background ButtonBackground -Resource
    Setter Foreground Foreground -Resource
}

Style MenuItem {
    Setter Background SurfaceBackground -Resource
    Setter Foreground Foreground -Resource
}
```

Controls are auto-styled at creation time if an implicit style exists for their exact type.

## Recommended pattern

1. Define themes first.
2. Define mostly implicit styles for common control types.
3. Use named styles only for special variants.
4. Apply startup theme from OS preference.
5. Expose a runtime toggle command.

Example:

```powershell
Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
    Brush 'Foreground' '#111111'
}

Theme 'Dark' {
    Brush 'WindowBackground' '#1E1E1E'
    Brush 'Foreground' '#F0F0F0'
}

Style Window {
    Setter Background WindowBackground -Resource
    Setter Foreground Foreground -Resource
}

Window 'Main' {
    $this.Tag = New-WPFObservableState @{
        CurrentTheme = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this
}
```

## Menu and MenuItem guidance

Do not copy a parent style object to child controls automatically.

Preferred approach:

- Define implicit `Menu` style.
- Define implicit `MenuItem` style.

This gives consistent visuals while keeping styles type-correct and predictable.

## Notes and limitations

- Implicit styles are keyed by target type full name.
- Auto-application checks the control `Style` property and only applies if no style is already set.
- `UseStyle` still overrides implicit defaults when needed.
- `MenuItem.Header` can contain spaces, but `MenuItem.Name` must be a valid WPF name.

## Troubleshooting

If theme toggle does not update a property:

1. Confirm style uses `Setter ... -Resource` (or `Resource ...`).
2. Confirm the resource key exists in both themes.
3. Confirm `Use-WPFTheme` is applied to the correct root element.
4. Confirm the property is a dependency property.

If `UseStyle` says a style is not registered:

1. Ensure named style uses `Style 'Name' TargetType { ... }`.
2. Ensure the style definition executes before control creation.
3. Re-import module/script if testing in an existing interactive session.
