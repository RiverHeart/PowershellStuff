function Invoke-ImageViewerToggleFigureDrawingMode {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if ($State.IsFigureDrawingMode) {
        Stop-ImageViewerSlideshow -Window $Window
        return
    }

    $defaultMinutes = if ($State.FigureDrawingTotalMinutes) {
        [int] $State.FigureDrawingTotalMinutes
    } else {
        20
    }

    $minutesInput = Get-WPFTextInput `
        -Prompt 'Enter figure drawing session minutes (1 to 600).' `
        -Title 'Start Figure Drawing Mode' `
        -DefaultValue $defaultMinutes.ToString([System.Globalization.CultureInfo]::InvariantCulture) `
        -Numeric `
        -Minimum 1 `
        -Maximum 600 `
        -Owner $Window

    if ([string]::IsNullOrWhiteSpace($minutesInput)) {
        return
    }

    [int] $totalMinutes = 0
    if (
        -not [int]::TryParse(
            $minutesInput,
            [System.Globalization.NumberStyles]::Integer,
            [System.Globalization.CultureInfo]::CurrentCulture,
            [ref] $totalMinutes
        )
    ) {
        return
    }

    Start-ImageViewerFigureDrawingMode -TotalMinutes $totalMinutes
}