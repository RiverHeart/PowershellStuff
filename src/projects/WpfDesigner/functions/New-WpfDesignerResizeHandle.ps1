using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a bottom-right resize handle for a selected control.

.DESCRIPTION
    Adds a small square Thumb to the canvas, pinned to the target's
    bottom-right corner. Dragging the handle adjusts the target's Width and
    Height (clamped to a 20px minimum) and keeps the handle pinned as the
    target's size changes.
#>
function New-WpfDesignerResizeHandle {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Primitives.Thumb])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target
    )

    # Thumb() auto-attaches to $this when set, so clear it first to guarantee
    # the handle stays unparented until we explicitly place it below.
    $this = $null
    $Handle = Thumb {
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

    # GetNewClosure() detaches the handler from module scope, so
    # Update-WpfDesignerResizeHandlePosition must be captured as a scriptblock
    # reference here rather than called by name below.
    $UpdatePosition = ${function:Update-WpfDesignerResizeHandlePosition}

    # Thumb.DragDelta gives incremental change since the last event, so no
    # anchor/mouse-capture bookkeeping is needed here.
    On -Event DragDelta -InputObject $Handle -ScriptBlock {
        param($sender, $e)

        $Target.Width = [System.Math]::Max(20, $Target.Width + $e.HorizontalChange)
        $Target.Height = [System.Math]::Max(20, $Target.Height + $e.VerticalChange)
        & $UpdatePosition -Handle $sender -Target $Target
    }.GetNewClosure()

    return $Handle
}

