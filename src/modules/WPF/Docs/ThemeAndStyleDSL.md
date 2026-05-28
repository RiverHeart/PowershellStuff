# WPF Theme and Style DSL Reference

## Table of Contents

* [Purpose](#purpose)
* [Keywords at a glance](#keywords-at-a-glance)
  * [Theme and resources](#theme-and-resources)
  * [Styles](#styles)
* [Style Setting](#style-setting)
  * [Implicit Setting](#implicit-setter)
  * [Explicit Setting](#explicit-setter)
  * [Scope and compatibility notes](#scope-and-compatibility-notes)
  * [Property resolution precedence and delimiter](#property-resolution-precedence-and-delimiter)
* [How dynamic theme updates work](#how-dynamic-theme-updates-work)
* [Style Scoping](#named-vs-implicit-styles)
  * [Named Styles](#named-styles)
  * [Typed Styles](#typed-styles)
* [Recommended Pattern](#recommended-pattern)

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
- `Theme` brush shorthand (new syntax option)
  - Inside a `Theme { ... }` block, top-level unknown commands are treated as implicit `Brush` calls.
  - Example: `WindowBackground '#1E1E1E'` is equivalent to `Brush 'WindowBackground' '#1E1E1E'`.
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
- `Style` property command shorthand (new syntax option)
  - Inside a `Style { ... }` block, top-level unknown commands are treated as implicit `Setter` calls.
  - Example: `Background '#F8FAFC'` is equivalent to `Setter Background '#F8FAFC'`.
- `Setter <Property> <Value> [-Resource]`
  - Adds a setter to the current style.
  - `-Resource` stores a `DynamicResource` reference.
- `UseStyle <Name> [-InputObject <Object>]`
  - Applies a named style to a target object.

## Theme brush shorthand syntax option

You can now choose either Theme body format:

### Explicit `Brush` form

```powershell
Theme 'Dark' {
  Brush 'WindowBackground' '#1E1E1E'
  Brush 'Foreground' '#F0F0F0'
}
```

### Implicit key command form

```powershell
Theme 'Dark' {
  WindowBackground: '#1E1E1E'
  Foreground: '#F0F0F0'
}
```

Both forms are supported and can be mixed.

### Theme shorthand limits

- Shorthand applies to top-level Theme resource entries.
- Existing `Brush` remains fully supported.
- Unlike `Setter`, `Brush` currently has no flags, so there is no flag-forwarding behavior to preserve.
- Extra trailing arguments on shorthand entries are rejected.

### Theme key resolution precedence and delimiter

To reduce key/keyword collisions in Theme shorthand, Theme blocks use this resolution order:

1. **Explicit key delimiter**: `Name:` always means a theme resource key shorthand entry.
2. **Reserved Theme keyword**: reserved Theme keywords remain explicit keywords (unless `Name:` is used).
3. **Normal command resolution**: existing commands/functions continue to run.
4. **Fallback shorthand**: unresolved names fall back to Theme shorthand and map to `Brush`.

Examples:

```powershell
Theme 'Dark' {
  WindowBackground '#1E1E1E'   # shorthand fallback
  WindowBackground: '#1E1E1E'  # explicit key mode
}
```

```powershell
Theme 'Demo' {
  Brush: '#445566'             # key named 'Brush' (not the Brush keyword)
}
```

## Style Setting

You can now choose either style body format:

### Implicit Setter

The new, recommended, implicit form inspects the AST of the scriptblock to distinguish
keywords from property commands and calls `Setter` for the latter.

```powershell
Style 'PrimaryButton' Button {
    Background ButtonBackground -Resource
    Foreground Foreground -Resource
    MinWidth 120
}
```

### Explicit Setter

The old, explicit form, calls `Setter` to set style properties.

```powershell
Style 'PrimaryButton' Button {
    Setter Background ButtonBackground -Resource
    Setter Foreground Foreground -Resource
    Setter MinWidth 120
}
```

Both forms are supported and equivalent for top-level style property setters.

### Scope and compatibility notes

- Shorthand applies to **top-level style property commands**.
- Existing DSL keywords still stay explicit: `Trigger`, `DataTrigger`, `MultiTrigger`, `Chrome`, `Template`, `ExtendStyle`.
- `Setter` continues to be fully supported and can be mixed with shorthand.
- Trigger and Chrome blocks also support property command shorthand that maps to `Setter`.
- Shorthand forwards remaining arguments to `Setter`, including supported flags such as `-Resource`.
- `Setter` flags that are context-specific remain context-specific with shorthand.
  - Example: `-Target` and `-Scope Chrome` are trigger/template-context features and are not valid on top-level style shorthand statements. Chrome trigger targeting is inferred by nesting `Trigger` inside `Chrome { ... }`.
- In template factory element blocks (for example `Border { ... }`, `ContentPresenter { ... }`, `ScrollViewer { ... }` inside `Template`), property command shorthand also maps to `Setter`.
- Template root blocks still use explicit DSL keywords (`Border`, `Trigger`, etc.); shorthand applies to factory element property statements, not Template-level orchestration.

### Property resolution precedence and delimiter

To reduce command/property collisions in implicit shorthand, style and template-factory contexts use this resolution order:

1. **Explicit property delimiter**: `Name:` always means property shorthand.
2. **Dependency property match**: if command name matches a dependency property on the current target type, treat it as property shorthand.
3. **Reserved DSL keyword**: reserved style DSL keywords remain explicit keywords (unless `Name:` is used).
4. **Normal command resolution**: existing commands/functions continue to run.
5. **Fallback shorthand**: unresolved names fall back to shorthand and are validated by `Setter`.

Examples:

```powershell
Style 'ExampleButton' Button {
  BorderBrush '#8E9AAF'     # property match
  BorderBrush: '#8E9AAF'    # explicit property mode
}
```

```powershell
Style 'ExampleButton' Button {
  Template {
    Border 'TemplateBorder' {
      Background: ButtonBackground -Resource
    }
  }
}
```

## How dynamic theme updates work

Theme toggling updates live only when styles/properties are bound through dynamic resources.

Use one of these:

- `Setter Background ButtonBackground -Resource`
- `Resource Background ButtonBackground`

Avoid hard-coded brush assignments when you expect runtime theme changes.

## Style Scoping

### Named Style

Use when a style is a specific variant and should be opt-in:

```powershell
Style 'PrimaryButton' Button {
  Background ButtonBackground -Resource
  Foreground Foreground -Resource
}

Button 'SaveButton' {
    UseStyle 'PrimaryButton'
}
```

### Typed Styles

Use when you want all controls of a given type to share defaults:

```powershell
Style Button {
  Background: ButtonBackground -Resource
  Foreground: Foreground -Resource
}

Style MenuItem {
  Background: SurfaceBackground -Resource
  Foreground: Foreground -Resource
}
```

Typed styles are auto-applied to applicable controls at creation time.

## Recommended pattern

1. Define themes first.
2. Define mostly implicit styles for common control types.
3. Use named styles only for special variants.
4. Apply startup theme from OS preference.
5. Expose a runtime toggle command.

Example:

```powershell
Theme 'Light' {
    WindowBackground: '#FFFFFF'
    Foreground: '#111111'
}

Theme 'Dark' {
    WindowBackground: '#1E1E1E'
    Foreground: '#F0F0F0'
}

Style Window {
  Background: WindowBackground -Resource
  Foreground: Foreground -Resource
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
- Style shorthand preserves normal PowerShell expression/value behavior in style bodies.

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
