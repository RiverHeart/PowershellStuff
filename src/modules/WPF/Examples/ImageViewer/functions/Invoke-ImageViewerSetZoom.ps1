function Invoke-ImageViewerSetZoom {
    [CmdletBinding()]
    param(
        [double] $Delta = 0,

        [switch] $Reset
    )

    $State = (Reference 'Window').Tag
    $Viewer = Reference 'Viewer'

    $State.IsFitMode = $false

    $ZoomLevel = if ($Reset) { 1.0 } else { [double] $State.ZoomLevel + $Delta }
    $ZoomLevel = [Math]::Max(0.10, [Math]::Min(8.00, $ZoomLevel))
    $ZoomLevel = [Math]::Round($ZoomLevel, 2)
    $State.ZoomLevel = $ZoomLevel

    # Apply transforms as a group to preserve both rotation and scale.
    $RotateTransform = [System.Windows.Media.RotateTransform]::new($State.RotationAngle)
    $ScaleTransform = [System.Windows.Media.ScaleTransform]::new($ZoomLevel, $ZoomLevel)
    $TransformGroup = [System.Windows.Media.TransformGroup]::new()
    $TransformGroup.Children.Add($RotateTransform)
    $TransformGroup.Children.Add($ScaleTransform)
    $Viewer.LayoutTransform = $TransformGroup

    Invoke-ImageViewerUpdateStatus
    Invoke-ImageViewerUpdateNavigationIconStyle
}
