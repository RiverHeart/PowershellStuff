Describe 'ImageViewer Example' -Tag 'ImageViewer-Example' {
    It 'Uses PreviewKeyDown on the window for keyboard navigation reliability' {
        $ScriptPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/ImageViewer.DSL.ps1'
        $Content = Get-Content -Path $ScriptPath -Raw

        $Content | Should -Match 'When\s+PreviewKeyDown\s*\{'
        $Content | Should -Not -Match 'When\s+KeyDown\s*\{'
    }

    It 'Only navigates left/right when the focused ScrollViewer is not horizontally scrollable' {
        $ScriptPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/ImageViewer.DSL.ps1'
        $Content = Get-Content -Path $ScriptPath -Raw

        $LeftPattern = '''Left''\s*\{\s*if \(Test-ImageViewerShouldNavigate\)'
        $SpacePattern = '''Space''\) \} \{\s*if \(\$event.Key -eq \[Key\]::Space -or \(Test-ImageViewerShouldNavigate\)\)'

        $Content | Should -Match $LeftPattern
        $Content | Should -Match $SpacePattern

        $HelperPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Test-ImageViewerShouldNavigate.ps1'
        $HelperContent = Get-Content -Path $HelperPath -Raw

        $HelperContent | Should -Match 'IsKeyboardFocusWithin'
        $HelperContent | Should -Match 'ScrollableWidth'
        $HelperContent | Should -Not -Match 'HorizontalOffset'
    }

    It 'Builds a deterministic figure drawing schedule for a 20-minute session' {
        $SchedulePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/New-ImageViewerFigureDrawSchedule.ps1'
        . $SchedulePath

        $Schedule = New-ImageViewerFigureDrawSchedule -TotalMinutes 20 -ImageCount 20 -Preset Balanced

        $Schedule.Preset | Should -Be 'Balanced'
        $Schedule.TotalSeconds | Should -Be 1200
        $Schedule.PlannedSeconds | Should -Be 1200
        $Schedule.RemainingSeconds | Should -Be 0
        $Schedule.PoseCount | Should -BeLessOrEqual 20
        $Schedule.DurationsSeconds[0] | Should -Be 30
        ($Schedule.DurationsSeconds -contains 300) | Should -BeTrue
        $Schedule.Limiter | Should -Be 'Time'
    }

    It 'Caps figure drawing schedule by image count when images are limited' {
        $SchedulePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/New-ImageViewerFigureDrawSchedule.ps1'
        . $SchedulePath

        $Schedule = New-ImageViewerFigureDrawSchedule -TotalMinutes 20 -ImageCount 6 -Preset Balanced

        $Schedule.PoseCount | Should -Be 6
        $Schedule.Limiter | Should -Be 'Images'
        $Schedule.RemainingSeconds | Should -BeGreaterThan 0
    }

    It 'Uses warmer timing in Warmup than StudyHeavy for equal session length' {
        $SchedulePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/New-ImageViewerFigureDrawSchedule.ps1'
        . $SchedulePath

        $Warmup = New-ImageViewerFigureDrawSchedule -TotalMinutes 20 -ImageCount 200 -Preset Warmup
        $StudyHeavy = New-ImageViewerFigureDrawSchedule -TotalMinutes 20 -ImageCount 200 -Preset StudyHeavy

        $WarmupShortCount = ($Warmup.DurationsSeconds | Where-Object { $_ -eq 30 }).Count
        $WarmupLongCount = ($Warmup.DurationsSeconds | Where-Object { $_ -ge 300 }).Count
        $StudyHeavyShortCount = ($StudyHeavy.DurationsSeconds | Where-Object { $_ -eq 30 }).Count
        $StudyHeavyLongCount = ($StudyHeavy.DurationsSeconds | Where-Object { $_ -ge 300 }).Count

        $Warmup.Preset | Should -Be 'Warmup'
        $StudyHeavy.Preset | Should -Be 'StudyHeavy'
        $WarmupShortCount | Should -BeGreaterThan $StudyHeavyShortCount
        $WarmupLongCount | Should -BeLessThan $StudyHeavyLongCount
    }

    It 'Uses F6 to toggle figure drawing mode through the time-based prompt flow' {
        $DslPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/ImageViewer.DSL.ps1'
        $DslContent = Get-Content -Path $DslPath -Raw

        $TogglePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Invoke-ImageViewerToggleFigureDrawingMode.ps1'
        $ToggleContent = Get-Content -Path $TogglePath -Raw

        $DslContent | Should -Match 'Invoke-ImageViewerToggleFigureDrawingMode'
        $ToggleContent | Should -Match 'Select figure drawing preset: 1=Warmup, 2=Balanced, 3=StudyHeavy'
        $ToggleContent | Should -Match 'Enter figure drawing session minutes \(1 to 600\)'
        $ToggleContent | Should -Match 'Start-ImageViewerFigureDrawingMode\s+-TotalMinutes\s+\$totalMinutes\s+-Preset\s+\$preset'
    }

    It 'Shows a right sidebar in figure drawing mode with countdown and pause/play controls' {
        $DslPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/ImageViewer.DSL.ps1'
        $DslContent = Get-Content -Path $DslPath -Raw

        $DslContent | Should -Match "Border 'FigureDrawingSidebar'"
        $DslContent | Should -Match 'Watch Visibility Window.Tag.IsFigureDrawingMode'
        $DslContent | Should -Match "Label 'FigureDrawingCountdownLabel'"
        $DslContent | Should -Match 'Watch Content Window.Tag.FigureDrawingCountdownText'
        $DslContent | Should -Match 'Invoke-ImageViewerToggleFigureDrawingPause'
    }

    It 'Formats figure drawing countdown values using TimeSpan text output' {
        $CountdownPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Invoke-ImageViewerUpdateFigureDrawingCountdown.ps1'
        $CountdownContent = Get-Content -Path $CountdownPath -Raw

        $CountdownContent | Should -Match 'TimeSpan\]::FromSeconds'
        $CountdownContent | Should -Match "ToString\('hh\\:mm\\:ss'\)"
        $CountdownContent | Should -Match 'FigureDrawingCountdownText\s*='

        ([TimeSpan]::FromSeconds(65)).ToString('hh\:mm\:ss') | Should -Be '00:01:05'
    }

    It 'Pins slideshow timer navigation to the window context id captured at start' {
        $StartPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Start-ImageViewerSlideshow.ps1'
        $StartContent = Get-Content -Path $StartPath -Raw

        $StartContent | Should -Match 'Get-WPFContextId\s+-InputObject\s+\$Window'
        $StartContent | Should -Match 'Invoke-ImageViewerNavigate\s+-Direction\s+Forward\s+-ContextId\s+\$TimerContextId'
    }

    It 'Pins figure drawing timer callbacks to the captured window context id' {
        $FigurePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Start-ImageViewerFigureDraw.ps1'
        $FigureContent = Get-Content -Path $FigurePath -Raw

        $FigureContent | Should -Match 'Get-WPFContextId\s+-InputObject\s+\$Window'
        $FigureContent | Should -Match 'Invoke-ImageViewerNavigate\s+-Direction\s+Forward\s+-ContextId\s+\$TimerContextId'
        $FigureContent | Should -Match 'Invoke-ImageViewerUpdateFigureDrawingCountdown\s+-ContextId\s+\$TimerContextId'
    }

    It 'Allows navigation helper to resolve window by explicit ContextId' {
        $NavigatePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Invoke-ImageViewerNavigate.ps1'
        $NavigateContent = Get-Content -Path $NavigatePath -Raw

        $NavigateContent | Should -Match '\[string\]\s+\$ContextId'
        $NavigateContent | Should -Match 'Get-WPFWindow\s+-ContextId\s+\$ContextId'
        $NavigateContent | Should -Match 'Reference\s+''Viewer''\s+-ContextId\s+\$ContextId'
    }
}
