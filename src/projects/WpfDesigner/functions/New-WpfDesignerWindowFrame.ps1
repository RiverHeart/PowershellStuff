using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates the abstract Window frame on the design surface.

.DESCRIPTION
    A real System.Windows.Window can't be embedded as a visual child of
    another element, so the exported Window's bounds are represented on the
    canvas as a resizable Border acting as window chrome instead. Reuses the
    existing selection/resize-handle mechanics (Select-WpfDesignerElement)
    rather than introducing a separate resize path for the frame.
#>
function New-WpfDesignerWindowFrame {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Border])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State
    )

    # Border() auto-attaches to $this when set, so clear it first to guarantee
    # the frame stays unparented until we place it on the canvas below. Left
    # nameless (like the resize handle Thumb) since there's only ever one and
    # it's tracked via State.WindowFrame instead of by-name lookup.
    #
    # Sized to comfortably fit inside the default window's viewport pane so it
    # doesn't overflow into neighboring panes before the user resizes anything.
    $this = $null
    $Frame = Border {
        $this.Width = 480
        $this.Height = 360
        $this.Background = 'White'
        $this.BorderBrush = '#666666'
        $this.BorderThickness = 2
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $Frame
    CanvasPosition -Left 20 -Top 20 -InputObject $Frame

    # GetNewClosure() detaches the handler from module scope, so
    # Select-WpfDesignerElement must be captured as a scriptblock reference
    # here rather than called by name below.
    $SelectHandler = ${function:Select-WpfDesignerElement}

    # The frame has no Draggable handler to mark the event Handled, so it must
    # do so itself to suppress the canvas-level deselect handler.
    On -Event MouseLeftButtonDown -InputObject $Frame -ScriptBlock {
        param($sender, $e)
        & $SelectHandler -Canvas $Canvas -Target $sender -State $State
        $e.Handled = $true
    }.GetNewClosure()

    $State.WindowFrame = $Frame

    return $Frame
}
