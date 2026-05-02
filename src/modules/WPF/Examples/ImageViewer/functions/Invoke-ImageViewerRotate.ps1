<#
.SYNOPSIS
    Rotates the displayed image by 90 degrees in the specified direction.
#>
function Invoke-ImageViewerRotate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Clockwise', 'CounterClockwise')]
        [string] $Direction
    )

    $State = (Reference 'Window').Tag
    $Viewer = Reference 'Viewer'

    if (-not $State.IsFileLoaded) {
        return
    }

    # Update rotation angle (normalize to 0-360 range).
    $RotationDelta = if ($Direction -eq 'Clockwise') { 90 } else { -90 }
    $State.RotationAngle = ($State.RotationAngle + $RotationDelta) % 360
    if ($State.RotationAngle -lt 0) {
        $State.RotationAngle += 360
    }

    # Apply transforms as a group to preserve both rotation and scale.
    $RotateTransform = [System.Windows.Media.RotateTransform]::new($State.RotationAngle)
    $ScaleTransform = [System.Windows.Media.ScaleTransform]::new($State.ZoomLevel, $State.ZoomLevel)
    $TransformGroup = [System.Windows.Media.TransformGroup]::new()
    $TransformGroup.Children.Add($RotateTransform)
    $TransformGroup.Children.Add($ScaleTransform)
    $Viewer.LayoutTransform = $TransformGroup

    # If we're in fit mode, recalculate to account for the new aspect ratio.
    if ($State.IsFitMode) {
        Invoke-ImageViewerFitToWindow
    }

    Invoke-ImageViewerUpdateStatus
}
