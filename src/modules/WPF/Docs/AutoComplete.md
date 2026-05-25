# WPF Autocomplete Support

This project currently supports WPF autocomplete through two practical mechanisms:

1. `Complete-WPFEvent`
2. Explicitly type-casting `$this` at the top of a DSL script block

## Event Completion

Use `Complete-WPFEvent` to discover and complete valid event names for WPF controls.

Example:

```powershell
Complete-WPFEvent -TypeName System.Windows.Window
```

This is the primary built-in autocomplete surface for event names in the DSL workflow.

## Property/Method Completion Hack for `$this`

In DSL control script blocks, static analysis does not always infer the runtime type of `$this`.
A practical workaround is to cast `$this` to the expected control type at the top of the block.

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

## Notes

- This is an intentional workaround to improve editor assistance in DSL script blocks.
- The cast is for tooling/autocomplete ergonomics and should not change runtime behavior when the control type is correct.
- If the cast type is incorrect, you may hide real issues or get confusing IntelliSense suggestions.
