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
    * [App](#app)
    * [Content](#content)
    * [Grid](#grid)
    * [Row](#row)
    * [Column](#column)
    * [Border](#border)
    * [ContentPresenter](#contentpresenter)
    * [Button](#button)
    * [Label](#label)
    * [TextBlock](#textblock)
    * [TextBox](#textbox)
    * [ComboBox](#combobox)
    * [ProgressBar](#progressbar)
    * [Image](#image)
    * [ScrollViewer](#scrollviewer)
    * [StackPanel](#stackpanel)
    * [DockPanel](#dockpanel)
    * [Canvas](#canvas)
    * [DataGrid](#datagrid)
    * [DataGridTextColumn](#datagridtextcolumn)
    * [ListView](#listview)
    * [GridView](#gridview)
    * [GridViewColumn](#gridviewcolumn)
    * [GridViewColumnHeader](#gridviewcolumnheader)
    * [DatePicker](#datepicker)
    * [Menu](#menu)
    * [MenuItem](#menuitem)
    * [StatusBar](#statusbar)
    * [Thumb](#thumb)
* [Shapes](#shapes)
    * [Path](#path)
    * [Rectangle](#rectangle)
* [Commands and Events](#commands-and-events)
    * [Command](#command)
    * [Key](#key)
    * [On](#on)
    * [When](#when)
    * [TimedEvent](#timedevent)
* [Binding and Resources](#binding-and-resources)
    * [State](#state)
    * [Bind](#bind)
    * [Link](#link)
    * [BindProperty](#bindproperty)
    * [Binding](#binding)
    * [ValueConverter](#valueconverter)
    * [Resources](#resources)
    * [Resource](#resource)
    * [Theme](#theme)
    * [Brush](#brush)
    * [LinearGradientBrush](#lineargradientbrush)
    * [GradientStopCollection](#gradientstopcollection)
    * [GradientStop](#gradientstop)
* [Styles](#styles)
    * [Style](#style)
    * [ExtendStyle](#extendstyle)
    * [Template](#template)
    * [TemplateBinding](#templatebinding)
    * [Setter](#setter)
    * [Chrome](#chrome)
    * [Trigger](#trigger)
    * [DataTrigger](#datatrigger)
    * [MultiTrigger](#multitrigger)
    * [UseStyle](#usestyle)
* [Lookup and Composition Helpers](#lookup-and-composition-helpers)
    * [Add-WPFType](#add-wpftype)
    * [Get-WPFChromeAdapter](#get-wpfchromeadapter)
    * [Register-WPFChromeAdapter](#register-wpfchromeadapter)
    * [Get-WPFCompletionType](#get-wpfcompletiontype)
    * [Register-WPFCompletionType](#register-wpfcompletiontype)
    * [Unregister-WPFCompletionType](#unregister-wpfcompletiontype)
    * [ConvertTo-KeyGesture](#convertto-keygesture)
    * [Dock](#dock)
    * [CanvasPosition](#canvasposition)
    * [BringToFront](#bringtofront)
    * [SendToBack](#sendtoback)
    * [Draggable](#draggable)
    * [Reference](#reference)
    * [Import](#import)
    * [Show-WPFWindow](#show-wpfwindow)
    * [New-WPFProject](#new-wpfproject)
    * [Get-WPFTextInput](#get-wpftextinput)
* [Application Storage](#application-storage)
    * [New-WPFAppStorage](#new-wpfappstorage)
    * [Get-WPFStoredItem](#get-wpfstoreditem)
    * [Set-WPFStoredItem](#set-wpfstoreditem)
    * [Remove-WPFStoredItem](#remove-wpfstoreditem)
* [Completers](#completers)
    * [Complete-WPFColor](#complete-wpfcolor)
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
- Tab completion for $this members is context-aware and resolves against the nearest enclosing DSL control command.
- Method tooltip signatures are derived from instance `PSObject` metadata when available, avoiding type-literal reflection members.
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

### App

Creates an application-oriented Window shell with a DockPanel root, a content
host, an optional footer region, and an implicit top-level Menu.

The App content host is a constrained fill region so viewport-based controls
(`ScrollViewer`, `DataGrid`, image surfaces) measure against finite available
space. If you want sequential stacking semantics, add a `StackPanel` inside
`Content` explicitly.

When an App window enters fullscreen through `Set-WPFWindowFullScreen`, the
shell temporarily removes the content host margin so viewport content can reach
the window edges, then restores the original margin when fullscreen exits.

Root-level `MenuItem` entries are routed into an implicit `Menu` when no explicit
`Menu` has been created yet, which makes simple app layouts easier to write.

Implicit app shell controls use reserved internal names with a `__` prefix
(for example, `__ExampleMenu` and `__ExampleContent`) to avoid collisions with
user-defined control names.

```powershell
App 'Example' {
    $this.Title = 'Example'
    MenuItem 'File/Open' { }
}
```

### Content

Routes a block into the App shell's main content host.

`Content` does not add an extra visual container. It forwards directly into
the App content host.

```powershell
App 'Example' {
    Content {
        Button 'SaveButton' {
            $this.Content = 'Save'
        }
    }
}
```

### Footer

Routes a block into the App shell's footer region, docked above the status bar.

```powershell
App 'Example' {
    Footer {
        StackPanel 'ActionRow' {
            $this.Orientation = 'Horizontal'

            Button 'SaveButton' {
                $this.Content = 'Save'
            }
        }
    }
}
```

### StatusBar

Creates a WPF `StatusBar`.

Plain child controls are added as items, but WPF may wrap them in generated
item containers. When you need layout behavior that applies to the arranged
container itself, such as right-docking content, use explicit `StatusBarItem`
 entries.

```powershell
StatusBar {
    StatusBarItem {
        Dock Left

        TextBlock 'StatusFileText' {
            $this.Text = 'Ready'
        }
    }

    StatusBarItem {
        Dock Right

        TextBlock 'StatusZoomText' {
            $this.Text = '100%'
        }
    }
}
```

### StatusBarItem

Creates a WPF `StatusBarItem`.

Supports named and nameless forms and is primarily useful when you want to
control status bar item container layout directly.

```powershell
StatusBarItem 'ZoomItem' {
    Dock Right

    TextBlock 'ZoomText' {
        $this.Text = '100%'
    }
}
```

### Grid

Creates a Grid and processes Row and Column specs.

Grid instances expose an `AllowPackedCells` note property. It defaults to `$false` so a cell must contain a single child unless the layout explicitly wraps multiple controls in a container. Set `AllowPackedCells = $true` to allow multiple returned children in the same cell.

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

### ContentPresenter

Creates a WPF `ContentPresenter` and supports named and nameless forms.

Inside `Template`, `ContentPresenter` emits a template factory node so it can
be nested under controls like `Grid`, `Border`, and `DockPanel`.

```powershell
ContentPresenter 'BodyPresenter' {
    Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
    Setter VerticalAlignment ([VerticalAlignment]::Stretch)
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

### ComboBox

Creates a ComboBox. Set `ItemsSource` directly or bind it to a collection, then use `SelectedItem` for the current selection.

```powershell
ComboBox 'Options' {
    $this.DisplayMemberPath = 'Name'
    BindProperty ItemsSource OptionsList
    BindProperty SelectedItem SelectedOption
}
```

### ProgressBar

Creates a ProgressBar. Configure determinate progress with `Minimum`, `Maximum`, and `Value`, or set `IsIndeterminate` for ongoing activity.

```powershell
ProgressBar 'LoadingIndicator' {
    $this.Minimum = 0
    $this.Maximum = 100
    $this.Value = 40
    $this.Orientation = [System.Windows.Controls.Orientation]::Horizontal
}
```

Custom control templates can provide the standard `PART_Track`, `PART_Indicator`, and `PART_GlowRect` template parts.

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

### Canvas

Creates a Canvas. Use `CanvasPosition` to place children with the
`Canvas.Left`/`Top`/`Right`/`Bottom` attached properties.

```powershell
Canvas 'Board' {
    Label 'Piece' {
        CanvasPosition -Left 10 -Top 20
    }
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

### ListView

Creates a ListView. Use a nested `GridView` block to define columns.

```powershell
ListView 'ProcessList' {
    $this.ItemsSource = Get-Process

    GridView {
        GridViewColumn {
            $this.Header = 'Name'
            $this.DisplayMemberBinding = [System.Windows.Data.Binding] 'ProcessName'
        }
    }
}
```

### GridView

Creates a GridView and auto-attaches it when declared inside a `ListView` block.

```powershell
ListView 'ProcessList' {
    GridView {
        GridViewColumn {
            $this.Header = 'Name'
        }
    }
}
```

### GridViewColumn

Creates a GridViewColumn and auto-attaches it when declared inside a `GridView` block.

```powershell
GridView {
    GridViewColumn {
        $this.Header = 'CPU'
        $this.DisplayMemberBinding = [System.Windows.Data.Binding] 'CPU'
    }
}
```

### GridViewColumnHeader

Creates a GridViewColumnHeader and assigns it to the parent `GridViewColumn` header.

```powershell
GridViewColumn {
    GridViewColumnHeader {
        $this.Content = 'CPU %'
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
            On Click { (Reference 'MainWindow').Close() }
        }
    }
}
```

### MenuItem

Creates a MenuItem. Supports path shorthand using slash-separated names.

```powershell
MenuItem '_File/_Open' {
    On Click { }
}
```

### StatusBar

Creates a StatusBar and docks it to the bottom of an App shell, below any
Footer region.

Supports named and nameless forms.

```powershell
App 'Example' {
    StatusBar {
        TextBlock 'ReadyText' {
            $this.Text = 'Ready'
        }
    }
}
```

### Thumb

Creates a WPF `Thumb`. `Thumb` has no content and is typically used inside a
custom template or control composition to provide drag behavior, handling
`DragStarted`, `DragDelta`, and `DragCompleted` events.

```powershell
Thumb 'Handle' {
    $this.Width = 12
    $this.Height = 12

    On DragDelta {
        param($sender, $e)
        Write-Host "$($e.HorizontalChange), $($e.VerticalChange)"
    }
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

### Rectangle

Creates a WPF Rectangle shape that can be used directly in a control body or
inside a template-like container.

```powershell
Border 'Banner' {
    Rectangle 'BannerFill' {
        $this.Width = 200
        $this.Height = 100
        $this.Fill = LinearGradientBrush {
            $this.StartPoint = '0,0'
            $this.EndPoint = '1,1'
            GradientStop 'Yellow' 0.0
            GradientStop 'Red' 0.25
            GradientStop 'Blue' 0.75
            GradientStop 'LimeGreen' 1.0
        }
    }
}
```

## Commands and Events

### Command

Creates or attaches a command and optionally binds shortcut gestures.

`Execute` and `CanExecute` are contextual child keywords of `Command`.
They are intended to be used inside a `Command { ... }` specification block.

Outside a control scriptblock, `Command 'Name' { ... }` returns a reusable
`WPF.CommandDefinition`. Pass that object to `Command` inside each control that
should use it. The command is materialized on first attachment, then the same
`ICommand` instance is reused by later attachments. Gestures belong to the
attachment site rather than the definition.

```powershell
$SaveCommand = Command 'Save' {
    Execute { Write-Host 'Saving...' }
    CanExecute { $IsFileLoaded }
}

Button 'SaveButton' {
    Command $SaveCommand
}

MenuItem '(F)ile/(S)ave' {
    Command $SaveCommand 'Ctrl+S'
}
```

Inline definitions remain supported:

```powershell
Button 'RunButton' {
    Command 'Run' {
        Write-Host 'Run command'
    }
}
```

Root definitions cannot declare gestures because they are not associated with
a window. Supply a gesture when attaching the definition to a control.

### NotifyCanExecuteChanged

Explicitly notifies relay commands that their `CanExecute` result may have
changed. Pass registered control names directly, or pipe controls, reusable
command definitions, or relay commands to the keyword.

When multiple targets expose the same command instance, that command is
notified once per invocation.

```powershell
NotifyCanExecuteChanged 'SaveButton', 'RefreshButton'
```

```powershell
Reference 'SaveButton', 'RefreshButton' | NotifyCanExecuteChanged
```

This keyword does not observe state or trigger automatically. Call it explicitly
after changing values used by a command's `CanExecute` block.

### Key

`Key` registers a handler for `PreviewKeyDown` on the current object. It is syntax sugar that wraps your action in gesture-matching logic and only invokes the action when the key and modifier combination matches. Internally, `Key` registers this wrapper through `On PreviewKeyDown`.

Use `Key` for concise gesture matching when you do not need full event-switch logic.

```powershell
Key 'Escape' {
    Write-Host 'Exit fullscreen'
}

Key 'Ctrl+Shift+S' {
    Write-Host 'Save As'
}
```

### On

Adds an event handler to the current object.

```powershell
On Click {
    Write-Host 'Clicked'
}
```

### When

Declares a state-reactive handler on the parent control. Fires when observable
state on `Tag` reaches or transitions through a specific value.

Handlers run with `$this` bound to the parent control, `$StateValue` set to the
new value, and `$PreviousStateValue` set to the prior value.

Fire when a state property becomes a target value:

```powershell
Button 'FitButton' {
    State @{ IsFitMode = $false }

    When -State IsFitMode -Becomes $true {
        Invoke-FitToWindow
    }
}
```

Fire on any change, or filter by transition:

```powershell
When -State RotationAngle -Changes {
    Write-Debug "Rotation is now $StateValue"
}

When -State IsFitMode -Changes -To $true {
    Invoke-FitToWindow
}

When -State IsFitMode -Changes -From $false -To $true {
    Invoke-FitToWindow
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

**Async context note**: In DispatcherTimer callbacks, capture and pass the window's ContextId explicitly to ensure helpers resolve to the correct window. See [AsyncContextPinning.md](AsyncContextPinning.md) for detailed guidance.

## Binding and Resources

### State

Creates observable state for the current DSL parent, enabling reactive UI updates via bindings and callbacks.

The common convention is to call `State` inside the root `Window` block. It initializes the parent object's `Tag` property with an observable object that implements WPF's `INotifyPropertyChanged`. Properties defined in State can be bound directly in templates or bound via the `Bind` keyword.

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
        On Click {
            $window = Reference 'Window'
            $window.Tag.Count++
        }
    }
}
```

Bind state changes with the `Bind` keyword:

```powershell
Window 'MyApp' {
    State @{
        IsLoading = $false
    }

    TextBlock 'Status' {
        Bind Visibility -To Window.Tag.IsLoading -Invert
    }
}
```

### Bind

Binds a target property to an observable state path.

```powershell
Bind Visibility -To Window.Tag.IsFullScreen -Invert
Bind IsEnabled -To Window.Tag.IsFileLoaded
```

### Link

Unified binding sugar that delegates to existing binding keywords.

`Link` is the only public command in its implementation group. Endpoint
resolution, value conversion, and route-specific connectors are internal and
are not exported as DSL keywords.

By default, `Link` applies values in one direction only (source -> target).
Use `-Sync` for supported two-way Property and State links.

Canonical directional form:

```powershell
Link <Source> -To <Target>
```

Examples:

```powershell
Link IsFileLoaded -To IsEnabled
Link Text -To SearchQuery
Link Text -To SearchQuery -Sync
```

Directional support in current version:

- `State -> Property`: supported
- `Property -> Property`: supported
- `Property -> State`: supported
- `State -> State`: supported (one-way)

For directional `Property -> Property`, `-Map`, `-Transform`, `-Default`, `-StrictMap`, and `-Invert` are not yet supported.
When both endpoint kinds are explicitly `Property`, `Link` uses only `-InputObject` (or the current `$this`) and does not require a window or State context.
For directional `Property -> State`, `-Transform`, `-Map`, `-Default`, and `-StrictMap` are supported.
For directional `Property -> State`, `-Map` and `-Transform` are mutually exclusive, and `-Default`/`-StrictMap` require `-Map`.
For directional `Property -> State`, `-Invert` is supported and is applied before `-Map`/`-Transform`.
For directional `State -> State`, source and target must be different state properties.

`-Sync` enables two-way synchronization for directional Property and State links:

```powershell
Link Text -To SearchQuery -Sync
Link IsEnabled -To IsEnabled -FromKind State -ToKind Property -Sync
```

`-Sync` is not supported for `Property -> Property` or `State -> State` links.
`-Sync` cannot be combined with `-Map`, `-Transform`, `-Default`, `-StrictMap`, or `-Invert`.

Use directional state -> property binding:

```powershell
Link IsFullScreen -To Visibility -Invert
```

Map state values without writing a converter block:

```powershell
Link IsCopyFeedbackActive -To ToolTip -Map @{
    $true  = 'Copied to clipboard'
    $false = 'Copy image to clipboard'
}
```

Map entries should be final values/objects, not deferred scriptblocks. For
control content values, evaluate the object at map creation time:

```powershell
Link IsCopyFeedbackActive -To Content -Map @{
    $true  = (Path 'images/clipboard-check-solid-full.svg' { UseStyle 'ImageViewer.IconPath' })
    $false = (Path 'images/clipboard-solid-full.svg' { UseStyle 'ImageViewer.IconPath' })
}
```

`-Map` also accepts `True`/`False` keys for boolean state values, and supports
`-Default` for unmatched values:

```powershell
Link FigureDrawingPreset -To Content -Map @{
    Quick    = '2 min'
    Balanced = '5 min'
    Long     = '10 min'
} -Default 'Custom'
```

#### Link resolution boundary

`Link` endpoints are exact member names, not WPF `Binding.Path` expressions.
Each endpoint is resolved against only:

- properties on the current control (or `-InputObject`)
- top-level properties in the root window State

This is a deliberate contract boundary, not a WPF limitation. `Link` eagerly
classifies both endpoint kinds before choosing a connector, while WPF paths and
inherited `DataContext` are late-bound and may not be resolvable when the UI is
built. Link routes also use different underlying mechanisms, including WPF
bindings and observable State callbacks, so paths and source selectors cannot
be forwarded consistently across every Property/State pairing.

An earlier target-first `Link` API did forward paths and source selectors to
`BindProperty`; canonical source-to-target syntax removed that route-specific
surface in favor of one predictable endpoint model. Supporting richer endpoints
again is possible, but would be a contract expansion rather than exposing a
capability that WPF lacks.

`Link` does not inspect the control's inherited or locally assigned
`DataContext`. It also does not accept WPF source selectors such as `-Source`,
`-ElementName`, `-Self`, or `-TemplatedParent`. Property-to-Property links use
the same current control for both endpoints, so a simple self-source binding
can still be written explicitly:

```powershell
Link ActualWidth -To Width -FromKind Property -ToKind Property
```

For example, a dotted WPF binding path is not a valid `Link` endpoint:

```powershell
# Link 'SelectedPokemon.Name' -To Text
# Fails because no exact member named 'SelectedPokemon.Name' exists.
BindProperty Text 'SelectedPokemon.Name'
```

A nested `DataContext` is another important distinction:

```powershell
Border {
    BindProperty DataContext Detail

    TextBlock {
        BindProperty Text Name
    }
}
```

Here, `Name` is read from the `TextBlock`'s inherited `DataContext`. Replacing
the last line with `Link Name -To Text` would not express that binding. Because
`TextBlock` itself has a `Name` property, `Link` can resolve it as a
Property-to-Property link on the control instead of reading `DataContext.Name`.

Use `BindProperty` when the source is:

- an inherited or local `DataContext`
- a dotted WPF binding path
- another element or explicit source object
- a relative source other than the current control, such as `TemplatedParent`
- a binding that needs `FallbackValue`, `TargetNullValue`, or other custom WPF binding configuration

Use `Link` when both endpoints are top-level members of the current control or
root window State and directional intent is the clearest way to describe the
relationship.

State-to-Property links preserve collection object identity. For example,
linking an `ObservableCollection` to `ItemsSource` keeps later collection
changes visible to the control:

```powershell
Link SourceItems -To ItemsSource
```

Use `Binding` directly when an advanced API requires a binding object, such as
a trigger, template, or data-grid column:

```powershell
$binding = Binding 'IsEnabled' -Self
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

When no source selector is specified, `BindProperty` uses the target's inherited
`DataContext`. Initialize that context before creating child bindings. This is
especially important when a panel changes its `DataContext` to a nested object:

```powershell
Window 'MyApp' {
    State @{
        Detail = [pscustomobject] @{ Name = '' }
    }

    Border {
        BindProperty DataContext Detail

        TextBlock {
            BindProperty Text Name
        }
    }
}
```

If `Detail` starts as `$null`, the child `Name` binding is temporarily unresolved
and `BindProperty` warns. Prefer a neutral initial object when it represents valid
application state. Alternatively, specify `-Source` when the source is known and
should not come from `DataContext`.

There are two different null cases when configuring a binding through
`-ScriptBlock`:

- `FallbackValue` is displayed when the source or binding path cannot be resolved.
- `TargetNullValue` is displayed when the path resolves but its value is `$null`.

```powershell
Image 'Preview' {
    BindProperty Source ImageUri -ScriptBlock {
        $this.FallbackValue = $PlaceholderImage
        $this.TargetNullValue = $PlaceholderImage
    }
}
```

With a value converter:

```powershell
Label 'Status' {
    BindProperty Content CurrentFile -Source (Reference 'Window').Tag -Converter {
        param($File)
        if ($File) { "File: $($File.Name)" } else { 'No file' }
    }
}
```

For properties that should update their source:

```powershell
ComboBox 'Picker' {
    BindProperty SelectedItem UserSelection -TwoWay
}
```

`-Converter` is shorthand for assigning a `New-WPFValueConverter` to the WPF
binding. `-TwoWay` sets the WPF binding mode to `TwoWay`. Use `-ScriptBlock` for
other binding properties such as `UpdateSourceTrigger`, `FallbackValue`, or
`TargetNullValue`, or to override the shorthand configuration.

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

### Resources

Evaluates a block against the current target's `ResourceDictionary`, mirroring
XAML `*.Resources` scopes.

Use this to declare brushes, styles, and other dictionary-backed values where
they should be resolved by normal WPF resource lookup.

```powershell
Window 'Main' {
    Resources {
        LinearGradientBrush 'GrayBlueGradientBrush' {
            $this.StartPoint = '0,0'
            $this.EndPoint = '1,1'
            GradientStop 'DarkGray' 0
            GradientStop '#CCCCFF' 0.5
            GradientStop 'DarkGray' 1
        }

        Style Button {
            Setter Background GrayBlueGradientBrush -Resource
            Setter Width 80
            Setter Margin 10
        }
    }
}
```

### Resource

Binds a dependency property to a WPF resource key through `DynamicResource`.

In WPF, a resource is a keyed entry in a `ResourceDictionary`, such as a brush,
style, or template. `Resource` is the consuming side: it applies that keyed
value to the current control or style target.

If you only need a brush or object inside one script, a PowerShell variable is
usually simpler. Use a WPF resource when the value should be named in the UI,
shared across controls, or updated by theme switching.

```powershell
Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
}

Window 'Main' {
    Resource WindowBackground Background
}
```

```powershell
Resource WindowBackground Background
```

### Theme

Defines a named theme dictionary.

```powershell
Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
}

Theme 'Accent' {
    LinearGradientBrush 'WindowBackground' {
        $this.StartPoint = '0,0'
        $this.EndPoint = '1,0'
        GradientStop '#FF0A84FF' 0
        GradientStop '#FF086FD5' 1
    }
}
```

### Brush

Adds a brush entry to the current `ResourceDictionary` scope, such as `Theme`
or `Resources`.

```powershell
Brush 'Foreground' '#111111'
```

### LinearGradientBrush

Creates a linear gradient brush. When called inside `Theme` or `Resources`, the
brush is stored as a keyed dictionary resource. In other contexts, the
configured brush object is returned so it can be assigned directly to
properties like `Fill`.

Configure the brush directly with `$this`. Keep Theme/Style shorthand for
property-like declarations; this keyword is plain WPF object configuration.

```powershell
$AccentBackground = LinearGradientBrush {
    $this.StartPoint = '0,0'
    $this.EndPoint = '1,0'
    GradientStop '#FF0A84FF' 0
    GradientStop '#FF086FD5' 1
}

Rectangle 'BannerFill' {
    $this.Fill = $AccentBackground
}
```

```powershell
Rectangle 'BannerFill' {
    $this.Fill = LinearGradientBrush {
        $this.StartPoint = '0,0'
        $this.EndPoint = '1,1'
        $this.GradientStops = GradientStopCollection {
            GradientStop 'Yellow' 0.0
            GradientStop 'Red' 0.25
            GradientStop 'Blue' 0.75
            GradientStop 'LimeGreen' 1.0
        }
    }
}
```

### GradientStopCollection

Creates a `GradientStopCollection` for use in `LinearGradientBrush`.

```powershell
$glassStops = GradientStopCollection {
    GradientStop 'WhiteSmoke' 0.2
    GradientStop 'Transparent' 0.4
    GradientStop 'WhiteSmoke' 0.5
    GradientStop 'Transparent' 0.75
    GradientStop 'WhiteSmoke' 0.9
    GradientStop 'Transparent' 1.0
}

$glassBrush = LinearGradientBrush {
    $this.StartPoint = '0,0'
    $this.EndPoint = '1,1'
    $this.GradientStops = $glassStops
}
```

### GradientStop

Adds a gradient stop to the current `LinearGradientBrush` or `GradientStopCollection`.

```powershell
LinearGradientBrush {
    GradientStop 'Yellow' 0.0
    GradientStop 'Red' 0.25
    GradientStop 'Blue' 0.75
    GradientStop 'LimeGreen' 1.0
}
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

### Template

Defines a `ControlTemplate` for the current style target type.

Nested controls inside `Template` are built as template-factory visual tree
nodes. Trigger and setter behavior remains the same as other style contexts.

In template factory contexts, shorthand setter values support the preferred
`(TemplateBinding PropertyName)` form.

The legacy `TemplateBinding PropertyName` string syntax remains supported for
compatibility.

```powershell
Style Button {
    Template {
        Grid {
            Border 'TemplateBorder' {
                Background: (TemplateBinding Background)

                ContentPresenter 'BodyPresenter' {
                    Content: (TemplateBinding Content)
                    Margin: 8
                }
            }
        }

        Trigger IsMouseOver $true {
            Setter Opacity 0.9 -Target 'TemplateBorder'
        }
    }
}
```

### TemplateBinding

Creates a `TemplateBindingExtension` for use inside `Template` visual trees.

Use it as a value expression in template factory setter shorthand.

```powershell
Background: (TemplateBinding Background)
Content: (TemplateBinding Content)
```

`TemplateBinding` must be used inside a `Template` context.

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

### Property Syntax Contract

For Theme and Style script bodies, property assignment uses the colon-delimited command form.

- Theme shorthand: `Key: Value` forwards to `Brush Key Value`.
- Style shorthand: `Property: Value` forwards to `Setter Property Value`.
- Object-configuration keywords use `$this` directly and do not participate in shorthand dispatch.
- Explicit `Brush`, `LinearGradientBrush`, and `Setter` calls remain fully supported.
- Bare command form without a colon (for example, `Background Value`) is not
    shorthand syntax and should be treated as normal command invocation behavior.

The shorthand dispatcher is implemented by function factories:

- `New-WPFThemePropertyHandler`
- `New-WPFStylePropertyHandler`

These factories populate shorthand function declarations for the current script scope so the forwarded calls run in the caller context without requiring recreation of user-authored script blocks.

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

Attached properties are supported through standard WPF binding path syntax.

```powershell
DataTrigger '(ToolTipService.IsEnabled)' $false -Self {
    Setter Opacity 0.6
}
```

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

### Add-WPFType

Annotates an object with WPF DSL metadata using a custom `PSTypeName`.

This is an advanced extension helper intended for custom DSL/control authors. Use it when you create WPF objects outside the built-in keywords and need the DSL to treat them like known control categories.

Examples include:

* Marking a custom control-like object as `Control`
* Marking a collection-owner object as `CollectorOwner`

```powershell
$Border = [System.Windows.Controls.Border]::new()
Add-WPFType -InputObject $Border -Type Control
```

```powershell
$Grid = [System.Windows.Controls.Grid]::new()
Add-WPFType -InputObject $Grid -Type CollectorOwner
```

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

### Get-WPFCompletionType

Returns currently registered custom completion type mappings used by `$this`
completion.

```powershell
Get-WPFCompletionType
Get-WPFCompletionType -Name FancyControl
```

### Register-WPFCompletionType

Registers or replaces a completion type mapping for a DSL keyword/control name.

```powershell
Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.TextBlock])
Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.TextBlock]) -Force
```

### Unregister-WPFCompletionType

Removes one or more completion type mappings.

```powershell
Unregister-WPFCompletionType -Name FancyControl
Unregister-WPFCompletionType -All
```

### ConvertTo-KeyGesture

Converts one or more gesture strings to WPF `KeyGesture` objects.

Useful when you need consistent parsing for keyboard shortcuts across custom
DSL helpers.

```powershell
$Gesture = ConvertTo-KeyGesture -InputObject 'Ctrl+Shift+S'
```

```powershell
$Gestures = ConvertTo-KeyGesture -InputObject @('Ctrl+S', 'F11')
```

### Dock

Sets the `DockPanel.Dock` attached property on the current object.

Use inside a DSL block to target `$this`, or pass `-InputObject` explicitly.

```powershell
StatusBarItem 'StatusZoomItem' {
    Dock Right
}
```

```powershell
Dock Top -InputObject $SomeControl
```

### CanvasPosition

Sets the `Canvas.Left`, `Canvas.Top`, `Canvas.Right`, `Canvas.Bottom`, and
`Panel.ZIndex` attached properties on the current object. Only the parameters
you supply are applied.

`-Left`/`-Right` and `-Top`/`-Bottom` are mutually exclusive pairs; supplying
both sides of an axis raises an error.

Use inside a DSL block to target `$this`, or pass `-InputObject` explicitly.

```powershell
Canvas 'Board' {
    Label 'Piece' {
        CanvasPosition -Left 10 -Top 20
    }
}
```

```powershell
CanvasPosition -Left 5 -ZIndex 2 -InputObject $SomeControl
```

### BringToFront

Sets `Panel.ZIndex` on the current object to one greater than the highest
`ZIndex` among its sibling elements, so it renders above the rest of its
parent Panel's children. The object must already be attached to a Panel.

```powershell
Canvas 'Board' {
    Label 'Back' { CanvasPosition -Left 0 -Top 0 }
    Label 'Front' {
        CanvasPosition -Left 0 -Top 0
        BringToFront
    }
}
```

### SendToBack

Sets `Panel.ZIndex` on the current object to one less than the lowest
`ZIndex` among its sibling elements, so it renders behind the rest of its
parent Panel's children. The object must already be attached to a Panel.

```powershell
Canvas 'Board' {
    Label 'Front' { CanvasPosition -Left 0 -Top 0 }
    Label 'Back' {
        CanvasPosition -Left 0 -Top 0
        SendToBack
    }
}
```

### Draggable

Wires up `MouseLeftButtonDown`/`MouseMove`/`MouseLeftButtonUp` handlers so the
current object can be dragged around its parent Canvas with the mouse.
Position updates go through `CanvasPosition`. The parent is resolved when a
drag starts, so `Draggable` can be called before the object is attached to its
final Canvas; if the parent isn't a Canvas at that point, a warning is written
and the drag is ignored.

Use `-BringToFrontOnDrag` to raise the object's `ZIndex` when a drag begins,
`-BoundToParent` to keep the object fully within its parent Canvas (clamped
using the Canvas's and object's actual size), and `-OnDragEnd` to run custom
logic (for example, persisting the final position) after the mouse is
released.

```powershell
Canvas 'Board' {
    Label 'Piece' {
        CanvasPosition -Left 10 -Top 10
        Draggable -BringToFrontOnDrag
    }
}
```

```powershell
Draggable -InputObject $SomeControl -BoundToParent
```

```powershell
Draggable -InputObject $SomeControl -OnDragEnd {
    param($Target)
    Write-Host "Dropped at $([System.Windows.Controls.Canvas]::GetLeft($Target)), $([System.Windows.Controls.Canvas]::GetTop($Target))"
}
```

### Get-WPFWindow

Gets the current root window for the resolved DSL context.

Prefer this for root-window access instead of relying on a specific registered
window name.

In async callbacks (for example `DispatcherTimer` ticks), capture a context id
once and call `Get-WPFWindow -ContextId` so delayed handlers remain pinned to
the originating window.

```powershell
$Window = Get-WPFWindow
```

```powershell
$ContextId = Get-WPFContextId
$Window = Get-WPFWindow -ContextId $ContextId
```

### Get-WPFContextId

Gets the current control context id for the resolved DSL context.

Use this when you need to pin later `Reference` or `Get-WPFWindow` calls to a
specific window context.

Helpers that accept `-ContextId`, such as `Set-WPFWindowFullScreen`, can be
kept on the originating window the same way in async callbacks.

```powershell
$ContextId = Get-WPFContextId
```

```powershell
$ContextId = Get-WPFContextId -InputObject $SomeControl
```

```powershell
$ContextId = Get-WPFContextId
Set-WPFWindowFullScreen -IsFullScreen $true -ContextId $ContextId
```

### Reference

Gets a registered object by name from the current window context.

If multiple windows register the same name, `Reference` resolves by the current DSL object context. Use `-ContextId` for explicit lookup.

```powershell
$Window = Get-WPFWindow
$Buttons = Reference 'BackButton', 'ForwardButton'
$ContextId = Get-WPFContextId
$Window = Get-WPFWindow -ContextId $ContextId
$Buttons = Reference 'BackButton', 'ForwardButton' -ContextId $ContextId
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

## Application Storage

These supporting commands provide durable, per-user storage for application data.
They are regular module commands rather than control keywords, so they can be used
before creating a WPF window. Stored values use JSON by default; specify
`-Format CliXml` when PowerShell-specific type fidelity is useful. Both formats
store data snapshots and do not restore custom class instances. Cache expiry,
schema versions, class reconstruction, and invalidation remain the application's
responsibility.

### New-WPFAppStorage

Creates an explicit storage context. By default, data is stored beneath
`%LOCALAPPDATA%\WPF\<Application>`. Specify `-Publisher` to use a different
application namespace.

```powershell
$Storage = New-WPFAppStorage -Application 'PokeBrowser'
```

### Get-WPFStoredItem

Reads and deserializes an item. A missing item returns no output; corrupt data
produces an error.

```powershell
$UserPreferences = Get-WPFStoredItem -Storage $Storage -Name 'UserPreferences'
```

### Set-WPFStoredItem

Serializes a value in the selected format and atomically replaces any item with
the same name and format. Concurrent writes to the same item are rejected.

```powershell
Set-WPFStoredItem -Storage $Storage -Name 'UserPreferences' -Value $UserPreferences
```

### Remove-WPFStoredItem

Removes an item when it exists. The command supports `-WhatIf` and `-Confirm`.

```powershell
Remove-WPFStoredItem -Storage $Storage -Name 'UserPreferences'
```

## Completers

### Complete-WPFColor

Completes WPF named colors and hexadecimal color values. Hexadecimal insertion
text is enclosed in quotes (for example, `'#FFFFFF'`) so PowerShell does not
interpret the hash as the start of a comment. The completion list displays the
unquoted value (for example, `#FFFFFF`).

```powershell
Complete-WPFColor -WordToComplete 'FFFFFF'
```

## Compatibility Note

The keyword contract is intentionally simple:

- Use trailing scriptblocks for control bodies.
- Build UI top-down through nesting.
- Prefer $this for current-object configuration.

If behavior changes are needed, update examples and tests in the same change.
