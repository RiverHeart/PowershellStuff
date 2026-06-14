function Invoke-ImageViewerToggleFigureDrawingMode {
    [CmdletBinding()]
    param()

    $Window = Get-WPFWindow
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if ($State.IsFigureDrawingMode) {
        Stop-ImageViewerSlideshow -Window $Window
        return
    }

    $defaultPreset = if ($State.FigureDrawingPreset) {
        [string] $State.FigureDrawingPreset
    } else {
        'Balanced'
    }

    $defaultPresetChoice = switch ($defaultPreset) {
        'Warmup' { '1' }
        'StudyHeavy' { '3' }
        default { '2' }
    }

    $presetInput = Get-WPFTextInput `
        -Prompt 'Select figure drawing preset: 1=Warmup, 2=Balanced, 3=StudyHeavy.' `
        -Title 'Figure Drawing Preset' `
        -DefaultValue $defaultPresetChoice `
        -Numeric `
        -Minimum 1 `
        -Maximum 3 `
        -Owner $Window

    if ([string]::IsNullOrWhiteSpace($presetInput)) {
        return
    }

    [int] $presetChoice = 0
    if (
        -not [int]::TryParse(
            $presetInput,
            [System.Globalization.NumberStyles]::Integer,
            [System.Globalization.CultureInfo]::CurrentCulture,
            [ref] $presetChoice
        )
    ) {
        return
    }

    $preset = switch ($presetChoice) {
        1 { 'Warmup' }
        3 { 'StudyHeavy' }
        default { 'Balanced' }
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

    Start-ImageViewerFigureDrawingMode -TotalMinutes $totalMinutes -Preset $preset
}
