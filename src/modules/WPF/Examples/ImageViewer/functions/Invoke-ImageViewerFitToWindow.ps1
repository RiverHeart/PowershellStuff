<#
.SYNOPSIS
    Calculates and applies the zoom level and transforms needed to fit
    the entire image within the available viewport of the ScrollViewer,
    accounting for current rotation and DPI settings.

.DESCRIPTION
    This function retrieves the current image and viewer state, calculates the
    available viewport size, and determines the necessary zoom level to fit the
    entire image within the viewport while preserving aspect ratio. It also
    accounts for any current rotation of the image to ensure the bounding box of
    the rotated image fits within the viewport.

    The function applies the calculated zoom level and rotation transforms to the
    image viewer. If the viewport size cannot be determined or if there is no
    image loaded, it will exit without making changes. Finally, it updates the
    status display to reflect the new zoom level and fit mode.

.NOTES
    The 96.0 constant is WPF’s baseline DPI for device-independent units.

    WPF layout measures size in device-independent pixels (DIPs), where:

        1 DIP = 1/96 inch

    Image metadata is often in physical pixels plus DPI (for example 300 DPI),
    so the conversion is:

        width in DIPs = pixel width × (96 / image DPI X)
        height in DIPs = pixel height × (96 / image DPI Y)

    DIP conversion normalizes images from different DPI sources into WPF’s layout
    coordinate system so our math can compare like-for-like units (viewport DIPs vs image DIPs).

    As an example, if an image is tagged 300 DPI, its displayed DIP size is smaller than
    its raw pixel count. If it is 96 DPI, the DIP size matches pixel count 1:1.
#>
function Invoke-ImageViewerFitToWindow {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }
    $State = $Window.Tag
    if (-not $State.IsFileLoaded) {
        return
    }

    $Viewer = Reference 'Viewer' -ContextId $ContextId
    $ScrollViewer = Reference 'ScrollViewer' -ContextId $ContextId
    $Source = $Viewer.Source
    if (-not ($Source -is [System.Windows.Media.Imaging.BitmapSource])) {
        return
    }

    # Ensure layout is up to date to get correct viewport dimensions after any pending changes.
    $ScrollViewer.UpdateLayout()

    # Viewport reflects the actual scrollable content slot after template chrome and scrollbars.
    # ActualWidth/ActualHeight can overestimate available image area and cause edge-case overflow.
    $ViewportWidth = [double] $ScrollViewer.ViewportWidth
    $ViewportHeight = [double] $ScrollViewer.ViewportHeight

    if ($ViewportWidth -le 0 -or $ViewportHeight -le 0) {
        Write-Debug "Viewport width or height ($ViewportWidth x $ViewportHeight) is zero or negative, falling back to ScrollViewer actual size."
        $ViewportWidth = [double] $ScrollViewer.ActualWidth
        $ViewportHeight = [double] $ScrollViewer.ActualHeight
    }

    if ($ViewportWidth -le 0 -or $ViewportHeight -le 0) {
        Write-Debug "Viewport width or height ($ViewportWidth x $ViewportHeight) is zero or negative, cannot fit to window."
        return
    }

    # Convert pixel dimensions to device-independent pixels (DIP) units based on DPI
    # to get correct physical size for fitting. DIP is the unit WPF layout and transforms
    # operate in.
    $DIPBaseline = 96.0
    $ImageWidth = if ($Source.DpiX -gt 0) {
        [double] $Source.PixelWidth * ($DIPBaseline / [double] $Source.DpiX)
    } else {
        [double] $Source.PixelWidth
    }
    $ImageHeight = if ($Source.DpiY -gt 0) {
        [double] $Source.PixelHeight * ($DIPBaseline / [double] $Source.DpiY)
    } else {
        [double] $Source.PixelHeight
    }

    if ($ImageWidth -le 0 -or $ImageHeight -le 0) {
        Write-Debug "Image width or height ($ImageWidth x $ImageHeight) is zero or negative, cannot fit to window."
        return
    }

    # Account for current rotation to determine the bounding box of the rotated image,
    # which is needed to fit it within the viewport.
    $RotationAngle = [double] $State.RotationAngle
    $RotationAngle = $RotationAngle % 360
    if ($RotationAngle -lt 0) {
        $RotationAngle += 360
    }

    # Calculate the axis-aligned bounding box of the rotated image to determine
    # how to fit it within the viewport.
    $Radians = $RotationAngle * ([Math]::PI / 180.0)
    $CosTheta = [Math]::Abs([Math]::Cos($Radians))
    $SinTheta = [Math]::Abs([Math]::Sin($Radians))

    # Guard against floating-point residue near right angles (e.g., cos(90deg)).
    if ($CosTheta -lt 1e-10) {
        $CosTheta = 0.0
    }
    if ($SinTheta -lt 1e-10) {
        $SinTheta = 0.0
    }

    # Fit against the axis-aligned bounds after rotation, then apply scale.
    $RotatedImageWidth = ($ImageWidth * $CosTheta) + ($ImageHeight * $SinTheta)
    $RotatedImageHeight = ($ImageWidth * $SinTheta) + ($ImageHeight * $CosTheta)

    if ($RotatedImageWidth -le 0 -or $RotatedImageHeight -le 0) {
        Write-Debug "Rotated image width or height ($RotatedImageWidth x $RotatedImageHeight) is zero or negative, cannot fit to window."
        return
    }

    # Calculate the zoom level needed to fit the entire rotated image within the viewport.
    $ZoomLevel = [Math]::Min($ViewportWidth / $RotatedImageWidth, $ViewportHeight / $RotatedImageHeight)
    $ZoomLevel = [Math]::Max(0.10, [Math]::Min(8.00, $ZoomLevel))
    $ZoomLevel = [Math]::Floor($ZoomLevel * 100.0) / 100.0
    $State.ZoomLevel = $ZoomLevel

    # Apply transforms as a group to preserve both rotation and scale.
    $RotateTransform = [System.Windows.Media.RotateTransform]::new($State.RotationAngle)
    $ScaleTransform = [System.Windows.Media.ScaleTransform]::new($ZoomLevel, $ZoomLevel)
    $TransformGroup = [System.Windows.Media.TransformGroup]::new()
    $TransformGroup.Children.Add($RotateTransform)
    $TransformGroup.Children.Add($ScaleTransform)
    $Viewer.LayoutTransform = $TransformGroup

    $State.IsFitMode = $true

    Invoke-ImageViewerUpdateStatus -Window $Window
}
