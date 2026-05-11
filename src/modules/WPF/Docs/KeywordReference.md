# WPF DSL Keyword Reference

This is a practical first-pass reference for currently exported DSL commands.

Scope of this page:

- Focus on syntax and intent
- Keep behavioral details brief
- Point to examples for deeper usage

## Core Pattern

Most control keywords follow this shape:

```powershell
ControlName 'Name' {
    # Set properties on $this
    # Add child controls
    # Add events with When
}
```

Behavior notes:

- Inside the scriptblock, $this is the object currently being configured.
- Controls created inside another control are auto-attached to the parent.
- Most controls return nothing when auto-attached, otherwise they return the created object.

## Controls

### Window

Creates a WPF Window.

```powershell
Window 'MainWindow' {
    $this.Title = 'My App'
}
```

### Grid

Creates a Grid and processes Row and Column specs.

```powershell
Grid 'Body' {
    Row {
        Column {
            Label 'Title' {}
        }
    }
}
```

### Row

Defines a row spec inside Grid.

```powershell
Row {
    Column { }
}

Row 'Fit' {
    Column { }
}

Row 'Expand*2' {
    Column { }
}
```

### Column

Defines a column spec inside Row.

```powershell
Column {
    Label 'A' {}
}

Column 'Fit' {
    Label 'B' {}
}

Column 'Expand*3' {
    Label 'C' {}
}
```

### Border

Creates a Border. Supports named and nameless forms.

```powershell
Border 'Card' {
    Label 'Header' {}
}

Border {
    Label 'BodyText' {}
}
```

### Button

Creates a Button.

```powershell
Button 'SaveButton' {
    $this.Content = 'Save'
}
```

### Label

Creates a Label.

```powershell
Label 'StatusLabel' {
    $this.Content = 'Ready'
}
```

### TextBlock

Creates a TextBlock.

```powershell
TextBlock 'InfoText' {
    $this.Text = 'Details'
}
```

### TextBox

Creates a TextBox.

```powershell
TextBox 'SearchText' {
    $this.Width = 250
}
```

### Image

Creates an Image control.

```powershell
Image 'Preview' {
    $this.StretchDirection = 'DownOnly'
}
```

### ScrollViewer

Creates a ScrollViewer.

```powershell
ScrollViewer 'Scroller' {
    Image 'Viewer' {}
}
```

### StackPanel

Creates a StackPanel.

```powershell
StackPanel 'Toolbar' {
    Button 'A' {}
    Button 'B' {}
}
```

### DockPanel

Creates a DockPanel.

```powershell
DockPanel 'Layout' {
    Label 'Left' {}
    Label 'Right' {}
}
```

### DataGrid

Creates a DataGrid. Use `$this.ItemsSource` to bind data and `$this.AutoGenerateColumns` to control column generation.

```powershell
DataGrid 'ProcessList' {
    $this.AutoGenerateColumns = $false
    $this.ItemsSource = Get-Process
    $this.Columns.Add([System.Windows.Controls.DataGridTextColumn] @{
        Header  = 'Name'
        Binding = [System.Windows.Data.Binding] 'ProcessName'
    })
}
```

### DatePicker

Creates a DatePicker.

```powershell
DatePicker 'StartDate' {
    $this.SelectedDate = [datetime]::Today
}
```

### Menu

Creates a Menu control.

```powershell
Menu 'TopMenu' {
    MenuItem '_File' {
        MenuItem '_Exit' {
            When Click { (Reference 'MainWindow').Close() }
        }
    }
}
```

### MenuBar

Creates a Menu intended for menu bar scenarios.

```powershell
MenuBar 'Menu' {
    MenuItem '_File/_Open' {
        When Click { }
    }
}
```

### MenuItem

Creates a MenuItem. Supports path shorthand using slash-separated names.

```powershell
MenuItem '_File/_Open' {
    When Click { }
}
```

## Shapes

### Path

Loads a path from an SVG file and returns a WPF Path shape.

```powershell
Path 'images/arrow-left.svg' {
    $this.Stretch = 'Uniform'
}
```

## Commands and Events

### Shortcut

Creates or references a RoutedUICommand and binds shortcut gestures and a handler.

```powershell
Command 'Open' {
    # Uses built-in ApplicationCommand if available
}

Command 'MyCommand' 'Ctrl+M' {
    Write-Host 'Run custom command'
}

Command 'SaveAs' 'Ctrl+Shift+S' {
    Execute { Write-Host 'Saving...' }
    CanExecute { $IsFileLoaded }
    # RelayCommand does not rely on CommandManager in this module,
    # so we refresh availability explicitly when file state changes.
    (Reference 'Window').Tag.SaveAsCommand = $this.Command
}
```

### When

Adds an event handler to the current object.

```powershell
When Click {
    Write-Host 'Clicked'
}
```

### TimedEvent

Creates and starts a DispatcherTimer, registers it by name for `Reference`, and ensures cleanup through window lifecycle registry clearing.

TimedEvent requires an explicit interval in milliseconds.

```powershell
TimedEvent 'RefreshProcess' 3000 {
    param($sender, $e)
    # Periodic work
}
```

```powershell
# Async mode: run work in a background runspace and update UI on completion
TimedEvent 'RefreshData' 3000 `
  -Work {
      Get-Process
  } `
  -OnComplete {
      param($processes, $sender)
      # $sender is the DispatcherTimer
      # Update UI state here
      $null = $processes
      $null = $sender
}
```

## Binding and Resources

### Watch

Binds a target property to an observable state path.

```powershell
Watch Visibility Window.Tag.IsFullScreen -Invert
Watch IsEnabled Window.Tag.IsFileLoaded
```

### Bind-Property

Binds a dependency property to a binding path, source, or relative source.

Use this to bind regular properties (like `TextBlock.Text`) to other control properties or observable sources.

```powershell
TextBlock 'ProcessCount' {
    Bind-Property Text ItemsSource.Count -Source (Reference 'ProcessList')
}
```

```powershell
Rectangle 'Loading' {
    Bind-Property Visibility IsLoading -Self
}
```

With a value converter:

```powershell
Label 'Status' {
    Bind-Property Content CurrentFile -Source (Reference 'Window').Tag -ScriptBlock {
        $this.Converter = New-WPFValueConverter {
            param($File)
            if ($File) { "File: $($File.Name)" } else { 'No file' }
        }
    }
}
```

### Binding

Creates a WPF Binding object for advanced scenarios like DataTrigger.

```powershell
DataTrigger (Binding 'IsEnabled' -Self) $false {
    Setter Opacity 0.85
}
```

```powershell
DataTrigger (Binding 'IsEnabled' -TemplatedParent) $false {
    Setter Opacity 0.6 -Target 'TemplateBorder'
}
```

### ValueConverter

Creates an `IValueConverter` from PowerShell scriptblocks for use with WPF bindings.

```powershell
Binding 'WorkingSet64' -ScriptBlock {
    $this.Converter = New-WPFValueConverter {
        param($Value)
        [math]::Round($Value / 1MB, 2)
    }
}
```

### Resource

Binds a dependency property to a dynamic resource key.

```powershell
Resource Background WindowBackground
```

### Theme

Defines a named theme dictionary.

```powershell
Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
}
```

### Brush

Adds a brush entry to the current Theme.

```powershell
Brush 'Foreground' '#111111'
```

## Styles

### Style

Defines named or implicit styles.

```powershell
Style 'PrimaryButton' Button {
    Setter Padding '12,6,12,6'
}

Style Button {
    Setter Margin '0,8,0,0'
}
```

### Setter

Adds a setter to the current style.

```powershell
Setter Background ButtonBackground -Resource
Setter Margin '0,8,0,0'
```

### Trigger

Adds a property trigger to the current Style or ControlTemplate.

```powershell
Style 'PrimaryButton' Button {
    Trigger IsMouseOver $true {
        Setter Opacity 0.85
    }
}
```

```powershell
# ControlTemplate scope supports SourceName and Setter -Target
Trigger IsEnabled $false -SourceName 'TemplateBorder' {
    Setter Opacity 0.6 -Target 'TemplateBorder'
}
```

### DataTrigger

Adds a data trigger to the current Style or ControlTemplate.

```powershell
Style 'PrimaryButton' Button {
    DataTrigger 'IsEnabled' $false -Self {
        Setter Opacity 0.85
    }
}
```

```powershell
DataTrigger (Binding 'IsEnabled' -TemplatedParent) $false {
    Setter Opacity 0.6 -Target 'TemplateBorder'
}
```

### MultiTrigger

Adds a multi-condition property trigger to the current Style or ControlTemplate.

```powershell
Style 'PrimaryButton' Button {
    MultiTrigger @(
        @{ Property = 'IsEnabled'; Value = $false }
        @{ Property = 'IsDefault'; Value = $true }
    ) {
        Setter Opacity 0.85
    }
}
```

```powershell
MultiTrigger @(
    @{ Property = 'IsEnabled'; Value = $false; SourceName = 'TemplateBorder' }
) {
    Setter Opacity 0.6 -Target 'TemplateBorder'
}
```

### UseStyle

Applies a named style to the current object.

```powershell
UseStyle 'PrimaryButton'
```

## Lookup and Composition Helpers

### Reference

Gets a registered object by name from the current window context.

If multiple windows register the same name, `Reference` resolves by the current DSL object context. Use `-ContextId` for explicit lookup.

```powershell
$Window = Reference 'Window'
$Buttons = Reference 'BackButton', 'ForwardButton'
$Window = Reference 'Window' -ContextId $Window._WPFContextId
```

### Import

Dot-sources script files into caller scope.

```powershell
Import './functions/*.ps1'
```

### Show-WPFWindow

Shows a WPF window modally and returns its dialog result.

For unattended automation, set environment variable `WPF_SMOKE_TEST=1` (also accepts `true`, `yes`, `on`) to auto-close windows after first render.

```powershell
Window 'Window' {
    $this.Title = 'Hello'
} | Show-WPFWindow
```

### New-WPFProject

Creates a generic WPF DSL project scaffold with a starter window script, style file, and conventional folders.

```powershell
New-WPFProject MyApp
```

```powershell
New-WPFProject MyApp C:\Projects
```

```powershell
New-WPFProject MyApp -Bare
```

### Get-WPFTextInput

Shows a native WPF modal input dialog with prompt text and returns entered text.

```powershell
$Interval = Get-WPFTextInput -Prompt 'Enter slideshow interval in seconds:' -Title 'Start Slideshow' -DefaultValue '3.0'
```

```powershell
$Interval = Get-WPFTextInput -Prompt 'Seconds:' -Title 'Slideshow' -DefaultValue '3.0' -Numeric -AllowDecimal -Minimum 0.5 -Maximum 600
```

## Compatibility Note

The keyword contract is intentionally simple:

- Use trailing scriptblocks for control bodies.
- Build UI top-down through nesting.
- Prefer $this for current-object configuration.

If behavior changes are needed, update examples and tests in the same change.
