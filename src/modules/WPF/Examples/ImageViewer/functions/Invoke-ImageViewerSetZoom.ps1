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

    if (-not ($Viewer.LayoutTransform -is [System.Windows.Media.ScaleTransform])) {
        $Viewer.LayoutTransform = [System.Windows.Media.ScaleTransform]::new(1.0, 1.0)
    }

    $Transform = [System.Windows.Media.ScaleTransform] $Viewer.LayoutTransform
    $Transform.ScaleX = $ZoomLevel
    $Transform.ScaleY = $ZoomLevel

    Invoke-ImageViewerUpdateStatus
}
