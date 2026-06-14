<#
.SYNOPSIS
    Rotates the displayed image by 90 degrees in the specified direction.

.DESCRIPTION
    This function rotates the image displayed in the ImageViewer by 90
    degrees either clockwise or counterclockwise. It updates the rotation angle
    in the state and applies the necessary transforms to the viewer.

    If the viewer is in fit mode, it also recalculates the fit to account for
    the new aspect ratio after rotation. If the ResetRotation switch is used,
    it resets the rotation angle to 0.

    Finally, it updates the status display to reflect the new rotation angle.

.EXAMPLE
    # Rotate the image 90 degrees clockwise
    Invoke-ImageViewerRotate -Direction Clockwise

.EXAMPLE
    # Rotate the image 90 degrees counterclockwise
    Invoke-ImageViewerRotate -Direction CounterClockwise

.EXAMPLE
    # Rotate the image to a specific angle (e.g., 180 degrees)
    Invoke-ImageViewerRotate -RotationAngle 180

.EXAMPLE
    # Reset the image rotation to 0 degrees
    Invoke-ImageViewerRotate -ResetRotation
#>
function Invoke-ImageViewerRotate {
    [CmdletBinding(DefaultParameterSetName = 'Rotate')]
    param(
        [Parameter(ParameterSetName = 'Rotate')]
        [ValidateSet('Clockwise', 'CounterClockwise')]
        [string] $Direction = 'Clockwise',

        [Parameter(ParameterSetName = 'Rotate')]
        [ValidateRange(0, 360)]
        [int] $RotationAngle = 90,

        [Parameter(Mandatory,ParameterSetName = 'Reset')]
        [switch] $ResetRotation,

        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    [System.Windows.Window] $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }
    [pscustomobject] $State = $Window.Tag
    [System.Windows.Controls.Image] $Viewer = Reference 'Viewer' -ContextId $ContextId

    if (-not $State.IsFileLoaded) {
        return
    }

    if ($ResetRotation) {
        $State.RotationAngle = 0
    } else {
        # Update rotation angle (normalize to 0-360 range).
        $RotationDelta = if ($Direction -eq 'Clockwise') { 90 } else { -90 }
        $State.RotationAngle = ($State.RotationAngle + $RotationDelta) % 360
        if ($State.RotationAngle -lt 0) {
            $State.RotationAngle += 360
        }
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
        Write-Debug "Recalculating fit to window after rotation. New rotation angle: $($State.RotationAngle) degrees."
        Invoke-ImageViewerFitToWindow -ContextId $ContextId
    }

    Invoke-ImageViewerUpdateStatus -Window $Window
}
