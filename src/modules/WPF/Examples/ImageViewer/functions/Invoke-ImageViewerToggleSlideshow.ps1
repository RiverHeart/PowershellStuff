function Invoke-ImageViewerToggleSlideshow {
    [CmdletBinding()]
    param()

    $Window = Get-WPFWindow
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if ($State.IsSlideshowActive) {
        Stop-ImageViewerSlideshow
        return
    }

    $defaultInterval = if ($State.AutoForwardIntervalSeconds) { [double] $State.AutoForwardIntervalSeconds } else { 3.0 }

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
