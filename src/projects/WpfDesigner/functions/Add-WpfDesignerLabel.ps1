using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a new Label on the design surface and makes it draggable.

.DESCRIPTION
    Backs the toolbar's "+ Label" button. Places the new Label at a staggered
    position so repeated clicks don't stack labels exactly on top of each other.
#>
function Add-WpfDesignerLabel {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State
    )

    # Label() auto-attaches to $this when set, so clear it first to guarantee
    # the new Label stays unparented until we place it on the canvas below.
    $this = $null
    $NewLabel = Label "Label_$([guid]::NewGuid().ToString('N'))" {
        $this.Content = 'Label'
        $this.Width = 100
        $this.Height = 26
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $NewLabel
    $StaggerOffset = 20 + (($Canvas.Children.Count - 1) % 8) * 24
    CanvasPosition -Left $StaggerOffset -Top $StaggerOffset -InputObject $NewLabel

    # GetNewClosure() detaches the handler from module scope, so
    # Select-WpfDesignerElement must be captured as a scriptblock reference
    # here rather than called by name below.
    $SelectHandler = ${function:Select-WpfDesignerElement}

    # Registered before Draggable so selection runs first. Draggable marks the
    # event Handled, which suppresses the canvas-level deselect handler.
    On -Event MouseLeftButtonDown -InputObject $NewLabel -ScriptBlock {
        param($sender, $e)
        & $SelectHandler -Canvas $Canvas -Target $sender -State $State
    }.GetNewClosure()

    Draggable -InputObject $NewLabel -BringToFrontOnDrag

    # Draggable's -BringToFrontOnDrag can raise this Label's ZIndex above an
    # existing resize handle's on every mousedown, so re-assert the handle on
    # top afterward (handledEventsToo: Draggable already marked the event
    # Handled). MouseMove keeps the handle pinned to the Label's position
    # while it's being dragged.
    $UpdatePosition = ${function:Update-WpfDesignerResizeHandlePosition}

    $NewLabel.AddHandler(
        [System.Windows.UIElement]::MouseLeftButtonDownEvent,
        [System.Windows.Input.MouseButtonEventHandler] {
            param($sender, $e)
            $HandleProperty = $sender.PSObject.Properties['_WPFDesignerResizeHandle']
            if ($HandleProperty -and $HandleProperty.Value) {
                BringToFront -InputObject $HandleProperty.Value
            }
        }.GetNewClosure(),
        $true
    )

    On -Event MouseMove -InputObject $NewLabel -ScriptBlock {
        param($sender, $e)
        $HandleProperty = $sender.PSObject.Properties['_WPFDesignerResizeHandle']
        if ($HandleProperty -and $HandleProperty.Value) {
            & $UpdatePosition -Handle $HandleProperty.Value -Target $sender
        }
    }.GetNewClosure()

    return $NewLabel
}
