using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a new control on the design surface and wires up the shared
    selection/drag/resize interactions.

.DESCRIPTION
    Shared "add a control of type X" path backing the toolbar's per-type
    functions (e.g. Add-WpfDesignerLabel, Add-WpfDesignerStackPanel). Places
    the new element at a staggered position so repeated clicks don't stack
    elements exactly on top of each other, then wires selection-on-click,
    dragging, and resize-handle/selection-outline tracking. Type-specific
    defaults (initial size, content, etc.) are supplied via -Configure.
#>
function Add-WpfDesignerControl {
    [CmdletBinding()]
    [OutputType([System.Windows.FrameworkElement])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State,

        [Parameter(Mandatory)]
        [string] $Type,

        [Parameter(Mandatory)]
        [scriptblock] $Configure
    )

    # The DSL keyword function (Label, StackPanel, ...) auto-attaches to $this
    # when set, so clear it first to guarantee the new element stays
    # unparented until we place it on the canvas below.
    $this = $null
    $NewElement = & $Type $Configure

    Add-WPFObject -InputObject $Canvas -ChildObjects $NewElement
    $StaggerOffset = 20 + (($Canvas.Children.Count - 1) % 8) * 24
    CanvasPosition -Left $StaggerOffset -Top $StaggerOffset -InputObject $NewElement

    # GetNewClosure() detaches the handler from module scope, so
    # Select-WpfDesignerElement must be captured as a scriptblock reference
    # here rather than called by name below.
    $SelectHandler = ${function:Select-WpfDesignerElement}

    # Registered before Draggable so selection runs first. Draggable marks the
    # event Handled, which suppresses the canvas-level deselect handler.
    On -Event MouseLeftButtonDown -InputObject $NewElement -ScriptBlock {
        param($sender, $e)
        & $SelectHandler -Canvas $Canvas -Target $sender -State $State
    }.GetNewClosure()

    Draggable -InputObject $NewElement -BringToFrontOnDrag -BoundToParent

    # Draggable's -BringToFrontOnDrag can raise this element's ZIndex above an
    # existing resize handle/selection outline on every mousedown, so
    # re-assert them on top afterward (handledEventsToo: Draggable already
    # marked the event Handled).
    $NewElement.AddHandler(
        [System.Windows.UIElement]::MouseLeftButtonDownEvent,
        [System.Windows.Input.MouseButtonEventHandler] {
            param($sender, $e)
            $OutlineProperty = $sender.PSObject.Properties['_WPFDesignerSelectionOutline']
            if ($OutlineProperty -and $OutlineProperty.Value) {
                BringToFront -InputObject $OutlineProperty.Value
            }
            $HandleProperty = $sender.PSObject.Properties['_WPFDesignerResizeHandle']
            if ($HandleProperty -and $HandleProperty.Value) {
                BringToFront -InputObject $HandleProperty.Value
            }
        }.GetNewClosure(),
        $true
    )

    # MouseMove keeps the outline/handle pinned to the element's position while
    # it's being dragged (SizeChanged alone only covers width/height changes).
    $UpdateOutlinePosition = ${function:Update-WpfDesignerSelectionOutlinePosition}
    $UpdateHandlePosition = ${function:Update-WpfDesignerResizeHandlePosition}

    On -Event MouseMove -InputObject $NewElement -ScriptBlock {
        param($sender, $e)
        $OutlineProperty = $sender.PSObject.Properties['_WPFDesignerSelectionOutline']
        if ($OutlineProperty -and $OutlineProperty.Value) {
            & $UpdateOutlinePosition -Outline $OutlineProperty.Value -Target $sender
        }
        $HandleProperty = $sender.PSObject.Properties['_WPFDesignerResizeHandle']
        if ($HandleProperty -and $HandleProperty.Value) {
            & $UpdateHandlePosition -Handle $HandleProperty.Value -Target $sender
        }
    }.GetNewClosure()

    return $NewElement
}
