# WPF DSL Keyword Reference

This is a practical first-pass reference for currently exported DSL commands.

Scope of this page:

- Focus on syntax and intent
- Keep behavioral details brief
- Point to examples for deeper usage

## Table of Contents

* [Core Pattern](#core-pattern)
* [Controls](#controls)
    * [Window](#window)
    * [Grid](#grid)
    * [Row](#row)
    * [Column](#column)
    * [Border](#border)
    * [Button](#button)
    * [Label](#label)
    * [TextBlock](#textblock)
    * [TextBox](#textbox)
    * [Image](#image)
    * [ScrollViewer](#scrollviewer)
    * [StackPanel](#stackpanel)
    * [DockPanel](#dockpanel)
    * [DataGrid](#datagrid)
    * [DataGridTextColumn](#datagridtextcolumn)
    * [DatePicker](#datepicker)
    * [Menu](#menu)
    * [MenuBar](#menubar)
    * [MenuItem](#menuitem)
* [Shapes](#shapes)
    * [Path](#path)
* [Commands and Events](#commands-and-events)
    * [Command](#command)
    * [When](#when)
    * [TimedEvent](#timedevent)
* [Binding and Resources](#binding-and-resources)
    * [State](#state)
    * [Watch](#watch)
    * [BindProperty](#bindproperty)
    * [Binding](#binding)
    * [ValueConverter](#valueconverter)
    * [Resource](#resource)
    * [Theme](#theme)
    * [Brush](#brush)
* [Styles](#styles)
    * [Style](#style)
    * [ExtendStyle](#extendstyle)
    * [Setter](#setter)
    * [Chrome](#chrome)
    * [Trigger](#trigger)
    * [DataTrigger](#datatrigger)
    * [MultiTrigger](#multitrigger)
    * [UseStyle](#usestyle)
* [Lookup and Composition Helpers](#lookup-and-composition-helpers)
    * [Get-WPFChromeAdapter](#get-wpfchromeadapter)
    * [Register-WPFChromeAdapter](#register-wpfchromeadapter)
    * [Reference](#reference)
    * [Import](#import)
    * [Show-WPFWindow](#show-wpfwindow)
    * [New-WPFProject](#new-wpfproject)
    * [Get-WPFTextInput](#get-wpftextinput)
* [Compatibility Note](#compatibility-note)


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
- Return behavior is based on the created control's parent state and whether the `WPFCollectChildren` is set to true in the caller scope.

## Controls

### Window

Creates a WPF Window.

When caller scope contains an `AutoCloseSeconds` bound parameter, auto-close is
wired automatically after first render (`ContentRendered`).

For unattended automation, set `WPF_AUTO_CLOSE_SECONDS` to a numeric value.
Set `WPF_AUTO_CLOSE_SECONDS=0` to close immediately after first render while
still exercising startup/render path.

After `Show-WPFWindow` returns, inspect `LastDialogCloseReason` to distinguish
between a normal/user close (`User`) and DSL auto-close (`AutoClose`).

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

When used inside `Grid -> Row -> Column` specs, `Border` participates in
grid placement like other controls, so row and column coordinates are applied
as expected.

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

### DataGridTextColumn

Creates a DataGridTextColumn and auto-attaches it when declared inside a `DataGrid` block.

The second argument can be either a binding path string or a pre-built `Binding` object.

```powershell
DataGrid 'ProcessList' {
    DataGridTextColumn 'Name' 'ProcessName' {
        $this.Width = [System.Windows.Controls.DataGridLength]::new(3, [System.Windows.Controls.DataGridLengthUnitType]::Star)
    }

    DataGridTextColumn 'CPU' (Binding 'CpuPercent') {
        UseStyle 'RightAlignedDataGridHeader' $this -TargetType HeaderStyle
        UseStyle 'RightAlignedDataGridCell' $this -TargetType ElementStyle
    }
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

### Command

Creates or references a RoutedUICommand and binds shortcut gestures and a handler.

`Execute` and `CanExecute` are contextual child keywords of `Command`.
They are intended to be used inside a `Command { ... }` specification block.

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

`Work` and `OnComplete` are contextual children of `TimedEvent` in async mode.
They are supplied as contextual child blocks inside the trailing scriptblock.

TimedEvent requires an explicit interval in milliseconds.

In async mode, `OnComplete` receives two parameters:

- `Result`: array of objects emitted by `Work`
- `Sender`: the DispatcherTimer instance

```powershell
TimedEvent 'RefreshProcess' 3000 {
    param($sender, $e)
    # Periodic work
}
```

```powershell
# Async mode using contextual child keywords
TimedEvent 'RefreshData' 3000 {
    Work {
        Get-Process
    }
    OnComplete {
        param($processes, $sender)
        $null = $processes
        $null = $sender
    }
}
```

## Binding and Resources

### State

Creates observable state for the current DSL parent, enabling reactive UI updates via bindings and callbacks.

The common convention is to call `State` inside the root `Window` block. It initializes the parent object's `Tag` property with an observable object that implements WPF's `INotifyPropertyChanged`. Properties defined in State can be bound directly in templates or watched via the `Watch` keyword.

PowerShell-side callback hooks are also supported through `AddBinding()`, which fires when the underlying property changes.

```powershell
Window 'MyApp' {
    State @{
        Count = 0
        IsReady = $false
        CurrentFile = $null
    }

    # Now use the state properties in bindings
    TextBlock 'Counter' {
        BindProperty Text Count -Self
    }
}
```

State properties are also accessible via `Window.Tag`:

State can also be attached to other DSL parents that expose a writable `Tag` property, though the root `Window` is the typical place to keep app-level state.

```powershell
Window 'MyApp' {
    State @{
        Count = 0
    }

    Button 'Increment' {
        When Click {
            $window = Reference 'Window'
            $window.Tag.Count++
        }
    }
}
```

Watch state changes with the `Watch` keyword:

```powershell
Window 'MyApp' {
    State @{
        IsLoading = $false
    }

    TextBlock 'Status' {
        Watch Visibility Window.Tag.IsLoading -Invert
    }
}
```

### Watch

Binds a target property to an observable state path.

```powershell
Watch Visibility Window.Tag.IsFullScreen -Invert
Watch IsEnabled Window.Tag.IsFileLoaded
```

### BindProperty

Binds a dependency property to a binding path, source, or relative source.

Use this to bind regular properties (like `TextBlock.Text`) to other control properties or observable sources.

```powershell
TextBlock 'ProcessCount' {
    BindProperty Text ItemsSource.Count -Source (Reference 'ProcessList')
}
```

```powershell
Rectangle 'Loading' {
    BindProperty Visibility IsLoading -Self
}
```

With a value converter:

```powershell
Label 'Status' {
    BindProperty Content CurrentFile -Source (Reference 'Window').Tag -ScriptBlock {
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

### ExtendStyle

Sets `BasedOn` for the current style.

Use target type names to inherit from an implicit style:

```powershell
Style Button {
    Setter FontSize 14
}

Style 'PrimaryButton' Button {
    ExtendStyle Button
    Setter Background '#0A84FF'
}
```

Use named style keys to inherit from another named style:

```powershell
Style 'ButtonBase' Button {
    Setter Padding '12,6,12,6'
}

Style 'ButtonAccent' Button {
    ExtendStyle 'ButtonBase'
    Setter Background '#0A84FF'
}
```

### Setter

Adds a setter in style, trigger, or template-factory contexts.

`Setter` resolves dependency properties for the current target context.
In template-backed trigger contexts, `-Target` can route values to named parts.
In triggers nested under `Chrome`, setters default to the generated chrome part.

```powershell
Setter Background ButtonBackground -Resource
Setter Margin '0,8,0,0'
```

Template-backed trigger contexts can route setters to the generated chrome part:

```powershell
Setter BorderBrush '#2563EB' -Scope Chrome
```

`-Scope Chrome` remains available for explicit setter routing in template-backed trigger contexts.

### Chrome

Defines a simplified template shell for supported controls.

The module includes a default adapter for `Button` styles. Additional target
types can be enabled by registering adapters with `Register-WPFChromeAdapter`.
Module-provided adapters are defined in dedicated adapter files under
`src/modules/WPF/Private/ChromeAdapters`.
Module-provided adapter factory functions use the `New-WPFFooChromeAdapter`
naming convention.

When a control is unsupported, the error reports that no adapter is registered
and lists currently registered adapter names.

Set `WPF_CHROME_WARN_UNMAPPED_SETTERS=1` to emit warnings for style setters that
are not copied into the generated chrome shell/content mapping. This is intended
as an opt-in debugging aid while keeping default output quiet.

```powershell
Style 'PrimaryButton' Button {
    Setter Background '#0A84FF'
    Setter Foreground '#FFFFFF'
    Setter Padding '14,8,14,8'

    Chrome {
        Setter CornerRadius 6
        Setter BorderBrush '#086FD5'
        Setter BorderThickness 2
    }
}
```

### Trigger

Adds a property trigger to the current Style, ControlTemplate, or Chrome block.

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

Triggers can be nested in `Chrome` to target the generated chrome part:

```powershell
Style 'PrimaryButton' Button {
    Chrome {
        Trigger IsEnabled $false {
            Setter BorderBrush '#2563EB'
        }
    }
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

`UseStyle` also supports applying styles to `DataGridTextColumn` style slots:

```powershell
UseStyle 'RightAlignedDataGridHeader' $this -TargetType HeaderStyle
UseStyle 'RightAlignedDataGridCell' $this -TargetType ElementStyle
```

## Lookup and Composition Helpers

### Get-WPFChromeAdapter

Returns currently registered Chrome adapters.

```powershell
Get-WPFChromeAdapter
Get-WPFChromeAdapter -TargetType ([System.Windows.Controls.Button])
```

### Register-WPFChromeAdapter

Registers or replaces a Chrome adapter mapping for a target control type.

```powershell
$adapterParams = @{
    TargetType = [System.Windows.Controls.Primitives.ToggleButton]
    ShellType = [System.Windows.Controls.Border]
    PartName = 'ToggleChrome'
    ShellPropertyMap = @{
        Background = [System.Windows.Controls.Border]::BackgroundProperty
        BorderBrush = [System.Windows.Controls.Border]::BorderBrushProperty
        BorderThickness = [System.Windows.Controls.Border]::BorderThicknessProperty
    }
    ContentPropertyMap = @{
        Padding = [System.Windows.FrameworkElement]::MarginProperty
        HorizontalContentAlignment = [System.Windows.FrameworkElement]::HorizontalAlignmentProperty
        VerticalContentAlignment = [System.Windows.FrameworkElement]::VerticalAlignmentProperty
    }
    ContentDefaults = @{
        HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
        VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    }
}

Register-WPFChromeAdapter @adapterParams
```

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

For unattended automation, `Show-WPFWindow` also honors `WPF_AUTO_CLOSE_SECONDS`
for direct `System.Windows.Window` instances that were not created through the DSL.

```powershell
Window 'Window' {
    $this.Title = 'Hello'
} | Show-WPFWindow
```

### New-WPFProject

Creates a generic WPF DSL project scaffold with a starter window script, style file, and conventional folders.

Default (non-`-Bare`) scaffolds include a small starter content area with example action buttons,
implemented using `StackPanel` layout only, and a style palette in the generated styles file:

- `PrimaryButton`
- `DangerButton`
- `GhostButton`

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

