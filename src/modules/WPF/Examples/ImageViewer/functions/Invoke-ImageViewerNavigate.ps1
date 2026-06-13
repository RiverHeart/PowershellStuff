function Invoke-ImageViewerNavigate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Back', 'Forward')]
        [string] $Direction,

        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }
    $State = $Window.Tag
    if (-not $State.IsFileLoaded) { return }
    $Navigator = $State.FileNavigator
    if (-not $Navigator.CurrentFile) { return }

    if ($Direction -eq 'Back') { $Navigator.MovePrevious() } else { $Navigator.MoveNext() }
    (Reference 'Viewer' -ContextId $ContextId).Source = $Navigator.CurrentFile.FullName
    Invoke-ImageViewerRotate -ResetRotation -ContextId $ContextId
    Invoke-ImageViewerFitToWindow -ContextId $ContextId
    Invoke-ImageViewerUpdateStatus -Window $Window
}
