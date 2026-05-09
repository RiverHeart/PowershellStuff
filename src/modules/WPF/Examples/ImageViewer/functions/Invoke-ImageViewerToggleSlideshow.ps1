function Invoke-ImageViewerToggleSlideshow {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if ($State.IsSlideshowActive) {
        Stop-ImageViewerSlideshow
        return
    }

    $defaultInterval = if ($State.SlideshowIntervalSeconds) { [double] $State.SlideshowIntervalSeconds } else { 3.0 }

    $intervalInput = Get-WPFTextInput `
        -Prompt 'Enter slideshow interval in seconds (0.5 to 600).' `
        -Title 'Start Slideshow' `
        -DefaultValue $defaultInterval.ToString([System.Globalization.CultureInfo]::InvariantCulture) `
        -Numeric `
        -AllowDecimal `
        -Minimum 0.5 `
        -Maximum 600 `
        -Owner $Window

    if ([string]::IsNullOrWhiteSpace($intervalInput)) {
        return
    }

    [double] $intervalSeconds = 0
    if (
        -not [double]::TryParse(
            $intervalInput,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::CurrentCulture,
            [ref] $intervalSeconds
        )
    ) {
        return
    }

    Start-ImageViewerSlideshow -IntervalSeconds $intervalSeconds
}
