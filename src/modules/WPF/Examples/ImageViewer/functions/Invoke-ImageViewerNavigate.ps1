function Invoke-ImageViewerNavigate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Back', 'Forward')]
        [string] $Direction
    )

    $State = (Get-WPFWindow).Tag
    if (-not $State.IsFileLoaded) { return }
    $Navigator = $State.FileNavigator
    if (-not $Navigator.CurrentFile) { return }

    if ($Direction -eq 'Back') { $Navigator.MovePrevious() } else { $Navigator.MoveNext() }
    (Reference 'Viewer').Source = $Navigator.CurrentFile.FullName
    Invoke-ImageViewerRotate -ResetRotation
    Invoke-ImageViewerFitToWindow
    Invoke-ImageViewerUpdateStatus
}
