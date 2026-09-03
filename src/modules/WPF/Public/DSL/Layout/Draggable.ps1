<#
.SYNOPSIS
    Wires up mouse-drag repositioning for the current DSL object inside a Canvas.

.DESCRIPTION
    Attaches MouseLeftButtonDown, MouseMove, and MouseLeftButtonUp handlers to
    the current object ($this) or an explicitly provided -InputObject so it can
    be dragged around its parent Canvas with the mouse. Position updates are
    applied through CanvasPosition.

    The target's parent is resolved when dragging starts, not when Draggable is
    called, so it is safe to call Draggable before the object is attached to
    its final Canvas. If the parent isn't a Canvas when a drag begins, a
    warning is written and the drag is ignored.

    This is a warning rather than a terminating error because the check runs
    inside a live MouseLeftButtonDown handler, not during synchronous DSL
    construction. Throwing there would surface as an unhandled exception in the
    WPF dispatcher loop, which risks destabilizing the running app instead of
    just failing a build/test run. A missing/incorrect Canvas parent can also
    be a transient, recoverable authoring state (for example, wiring Draggable
    before a later reparent), so silently ignoring the drag is safer than
    hard-failing unconditionally.

.EXAMPLE
    Canvas 'Board' {
        Label 'Piece' {
            CanvasPosition -Left 10 -Top 10
            Draggable
        }
    }

.EXAMPLE
    Draggable -BringToFrontOnDrag -InputObject $SomeControl

.EXAMPLE
    Run custom logic (for example, persisting the final position) after a drag ends.

    Draggable -OnDragEnd { param($Target) Write-Host "Dropped at $(
        [System.Windows.Controls.Canvas]::GetLeft($Target)), $(
        [System.Windows.Controls.Canvas]::GetTop($Target))" }
#>
function Draggable {
    [CmdletBinding()]
    [Alias('-Draggable')]
    [OutputType([void])]
    param(
        [switch] $BringToFrontOnDrag,

        [scriptblock] $OnDragEnd,

        [object] $InputObject
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name 'Draggable'
        return
    }

    $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
    if ($null -eq $Target) {
        Write-Error 'Draggable: Could not resolve target object. Use Draggable inside a DSL object block or pass -InputObject.'
        return
    }

    # Shared across the three handlers below via GetNewClosure() so each dragged control gets its own state.
    $DragState = [pscustomobject] @{
        IsDragging  = $false
        AnchorMouse = $null
        AnchorLeft  = 0.0
        AnchorTop   = 0.0
    }

    # GetNewClosure() detaches the handler from module scope, so private functions
    # must be captured as a scriptblock reference here rather than called by name below.
    $ComputeDraggedPosition = ${function:Get-WPFDraggedPosition}

    $MouseDownHandler = {
        param($sender, $e)

        $Parent = $sender.Parent
        if ($Parent -isnot [System.Windows.Controls.Canvas]) {
            Write-Warning "Draggable: '$($sender.Name)' must be attached to a Canvas to be dragged."
            return
        }

        $DragState.IsDragging = $true
        $DragState.AnchorMouse = $e.GetPosition($Parent)

        $Left = [System.Windows.Controls.Canvas]::GetLeft($sender)
        $DragState.AnchorLeft = if ([double]::IsNaN($Left)) { 0.0 } else { $Left }

        $Top = [System.Windows.Controls.Canvas]::GetTop($sender)
        $DragState.AnchorTop = if ([double]::IsNaN($Top)) { 0.0 } else { $Top }

        if ($BringToFrontOnDrag) {
            BringToFront -InputObject $sender
        }

        $sender.CaptureMouse()
        $e.Handled = $true
    }.GetNewClosure()

    $MouseMoveHandler = {
        param($sender, $e)

        if (-not $DragState.IsDragging) { return }

        $CurrentMouse = $e.GetPosition($sender.Parent)
        $NewPosition = & $ComputeDraggedPosition `
            -AnchorLeft $DragState.AnchorLeft `
            -AnchorTop $DragState.AnchorTop `
            -AnchorMouse $DragState.AnchorMouse `
            -CurrentMouse $CurrentMouse

        CanvasPosition -Left $NewPosition.Left -Top $NewPosition.Top -InputObject $sender
    }.GetNewClosure()

    $MouseUpHandler = {
        param($sender, $e)

        if (-not $DragState.IsDragging) { return }

        $DragState.IsDragging = $false
        $sender.ReleaseMouseCapture()

        if ($OnDragEnd) {
            & $OnDragEnd $sender
        }
    }.GetNewClosure()

    On -Event 'MouseLeftButtonDown' -ScriptBlock $MouseDownHandler -InputObject $Target
    On -Event 'MouseMove' -ScriptBlock $MouseMoveHandler -InputObject $Target
    On -Event 'MouseLeftButtonUp' -ScriptBlock $MouseUpHandler -InputObject $Target
}
