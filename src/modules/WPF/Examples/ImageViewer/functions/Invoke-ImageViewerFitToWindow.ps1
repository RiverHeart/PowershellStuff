function Invoke-ImageViewerFitToWindow {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
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

    $ViewportWidth = [double] $ScrollViewer.ActualWidth
    $ViewportHeight = [double] $ScrollViewer.ActualHeight
    if ($ViewportWidth -le 0 -or $ViewportHeight -le 0) {
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
        return
    }

    $ZoomLevel = [Math]::Min($ViewportWidth / $ImageWidth, $ViewportHeight / $ImageHeight)
    $ZoomLevel = [Math]::Max(0.10, [Math]::Min(8.00, $ZoomLevel))
    $ZoomLevel = [Math]::Round($ZoomLevel, 2)
    $State.ZoomLevel = $ZoomLevel

    if (-not ($Viewer.LayoutTransform -is [System.Windows.Media.ScaleTransform])) {
        $Viewer.LayoutTransform = [System.Windows.Media.ScaleTransform]::new(1.0, 1.0)
    }

    $Transform = [System.Windows.Media.ScaleTransform] $Viewer.LayoutTransform
    $Transform.ScaleX = $ZoomLevel
    $Transform.ScaleY = $ZoomLevel

    Invoke-ImageViewerUpdateStatus
}
