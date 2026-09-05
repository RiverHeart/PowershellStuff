using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a bottom-right resize handle for a selected control.

.DESCRIPTION
    Adds a small square handle to the canvas, pinned to the target's
    bottom-right corner. Dragging the handle adjusts the target's Width and
    Height (clamped to a 20px minimum) and keeps the handle pinned as the
    target's size changes.
#>
function New-WpfDesignerResizeHandle {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Border])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target
    )

    # Border() auto-attaches to $this when set, so clear it first to guarantee
    # the handle stays unparented until we explicitly place it below.
    $this = $null
    $Handle = Border {
        $this.Width = 8
        $this.Height = 8
        $this.Background = 'White'
        $this.BorderBrush = '#2563EB'
        $this.BorderThickness = 1
        $this.Cursor = 'SizeNWSE'
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $Handle
    BringToFront -InputObject $Handle
    Update-WpfDesignerResizeHandlePosition -Handle $Handle -Target $Target

    $DragState = [pscustomobject] @{
        IsDragging = $false
        AnchorMouse = $null
        AnchorWidth = 0.0
        AnchorHeight = 0.0
    }

    # GetNewClosure() detaches the handlers from module scope, so
    # Update-WpfDesignerResizeHandlePosition must be captured as a scriptblock
    # reference here rather than called by name below.
    $UpdatePosition = ${function:Update-WpfDesignerResizeHandlePosition}

    $MouseDownHandler = {
        param($sender, $e)

        $DragState.IsDragging = $true
        $DragState.AnchorMouse = $e.GetPosition($Canvas)
        $DragState.AnchorWidth = $Target.Width
        $DragState.AnchorHeight = $Target.Height
        $sender.CaptureMouse()
        $e.Handled = $true
    }.GetNewClosure()

    $MouseMoveHandler = {
        param($sender, $e)

        if (-not $DragState.IsDragging) {
            return
        }

        $Current = $e.GetPosition($Canvas)
        $Target.Width = [System.Math]::Max(20, $DragState.AnchorWidth + ($Current.X - $DragState.AnchorMouse.X))
        $Target.Height = [System.Math]::Max(20, $DragState.AnchorHeight + ($Current.Y - $DragState.AnchorMouse.Y))
        & $UpdatePosition -Handle $sender -Target $Target
    }.GetNewClosure()

    $MouseUpHandler = {
        param($sender, $e)

        if (-not $DragState.IsDragging) {
            return
        }

        $DragState.IsDragging = $false
        $sender.ReleaseMouseCapture()
    }.GetNewClosure()

    On -Event MouseLeftButtonDown -InputObject $Handle -ScriptBlock $MouseDownHandler
    On -Event MouseMove -InputObject $Handle -ScriptBlock $MouseMoveHandler
    On -Event MouseLeftButtonUp -InputObject $Handle -ScriptBlock $MouseUpHandler

    return $Handle
}

