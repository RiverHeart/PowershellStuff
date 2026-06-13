function Invoke-ImageViewerFitToWindow {
    [CmdletBinding()]
    param()

    $Window = Get-WPFWindow
    $State = $Window.Tag
    if (-not $State.IsFileLoaded) {
        return
    }

    $Viewer = Reference 'Viewer'
    $ScrollViewer = Reference 'ScrollViewer'
    $Source = $Viewer.Source
    if (-not ($Source -is [System.Windows.Media.Imaging.BitmapSource])) {
        return
    }

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

    $ImageWidth = if ($Source.DpiX -gt 0) {
        [double] $Source.PixelWidth * (96.0 / [double] $Source.DpiX)
    } else {
        [double] $Source.PixelWidth
    }
    $ImageHeight = if ($Source.DpiY -gt 0) {
        [double] $Source.PixelHeight * (96.0 / [double] $Source.DpiY)
    } else {
        [double] $Source.PixelHeight
    }

    if ($ImageWidth -le 0 -or $ImageHeight -le 0) {
        Write-Debug "Image width or height ($ImageWidth x $ImageHeight) is zero or negative, cannot fit to window."
        return
    }

    $ZoomLevel = [Math]::Min($ViewportWidth / $ImageWidth, $ViewportHeight / $ImageHeight)
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

    Invoke-ImageViewerUpdateStatus
}
