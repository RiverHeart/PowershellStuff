function Stop-ImageViewerSlideshow {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    $State = $Window.Tag

    if ($State.SlideshowTimer) {
        $State.SlideshowTimer.Stop()
    }

    $State.IsSlideshowActive = $false
}
