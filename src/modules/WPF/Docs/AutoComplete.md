# WPF Autocomplete Support

This project currently supports WPF autocomplete through these mechanisms:

1. `Complete-WPFEvent`
2. `Complete-WPFThis`
3. Explicitly type-casting `$this` at the top of a DSL script block (fallback)

## Event Completion

Use `Complete-WPFEvent` to discover and complete valid event names for WPF controls.

Example:

```powershell
Complete-WPFEvent -TypeName System.Windows.Window
```

This is the primary built-in autocomplete surface for event names in the DSL workflow.

## `$this` Member Completion

`Complete-WPFThis` is used by the WPF `TabExpansion2` override to provide
property and method completion for `$this.<member>` inside DSL control
scriptblocks.

Context is resolved from AST command ancestry and validated against known WPF
control types, so nested helper commands still complete against the enclosing
control block.

Example:

```powershell
Button 'SaveButton' {
    $this.Co<Tab>
}
```

Expected completions include members like `$this.Content`,
`$this.ContextMenu`, and method entries such as `$this.Focus(` for a `Button`
block.

`$this` completion metadata is discovered from the resolved .NET type (reflection)
and, when an instance can be created, `PSObject` members so that completions reflect
the control instance API instead of type-literal reflection members and so overload
definitions are properly formatted for the tooltip (as they require param names in the signature).

### Completion Hinting

In the event that custom completion fails, you can cast `$this` to the expected control type at the top
of the scriptblock. This is enough signal for regular TabExpansion2 to work.

Example:

```powershell
Window 'Window' {
    $this = [System.Windows.Window]$this
    $this.Title = 'TaskManager'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
}
```

You can apply the same pattern in other control blocks with the matching type, for example:

```powershell
DataGrid 'ProcessList' {
    $this = [System.Windows.Controls.DataGrid]$this
    $this.AutoGenerateColumns = $false
}
```
