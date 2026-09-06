using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a new control on the design surface and wires up the shared
    selection/drag/resize interactions.

.DESCRIPTION
    Shared "add a control of type X" path backing the toolbar's per-type
    functions (e.g. Add-WpfDesignerLabel, Add-WpfDesignerStackPanel). When the
    current selection is a valid container with room for another child (the
    Window frame, or a StackPanel), the new element is nested inside it;
    otherwise it floats directly on the canvas at a staggered position so
    repeated clicks don't stack elements exactly on top of each other. Wires
    selection-on-click, dragging, and resize-handle/selection-outline
    tracking either way. Type-specific defaults (initial size, content, etc.)
    are supplied via -Configure; pass -Container for control types that
    should themselves become valid drop targets for later placements.
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
        [scriptblock] $Configure,

        [switch] $Container
    )

    # The DSL keyword function (Label, StackPanel, ...) auto-attaches to the
    # ambient WPFAutoAttachContext when set, so clear it first to guarantee
    # the new element stays unparented until we place it on the canvas below.
    $WPFAutoAttachContext = $null
    $NewElement = & $Type $Configure

    if ($Container) {
        Add-WpfDesignerContainerMarker -InputObject $NewElement
    }

    $Selected = $State.SelectedElement
    $ParentContainer = if (
        $Selected -and
        (Test-WpfDesignerContainer -InputObject $Selected) -and
        (Test-WpfDesignerContainerCapacity -Container $Selected)
    ) {
        $Selected
    } else {
        $Canvas
    }

    Add-WPFObject -InputObject $ParentContainer -ChildObjects $NewElement
    if ($ParentContainer -eq $Canvas) {
        $StaggerOffset = 20 + (($Canvas.Children.Count - 1) % 8) * 24
        CanvasPosition -Left $StaggerOffset -Top $StaggerOffset -InputObject $NewElement
    }

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
            & $UpdateOutlinePosition -Outline $OutlineProperty.Value -Target $sender -Canvas $Canvas
        }
        $HandleProperty = $sender.PSObject.Properties['_WPFDesignerResizeHandle']
        if ($HandleProperty -and $HandleProperty.Value) {
            & $UpdateHandlePosition -Handle $HandleProperty.Value -Target $sender -Canvas $Canvas
        }
    }.GetNewClosure()

    return $NewElement
}
