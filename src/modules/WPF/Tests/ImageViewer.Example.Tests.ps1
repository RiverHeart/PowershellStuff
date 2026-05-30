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

        $Schedule = New-ImageViewerFigureDrawSchedule -TotalMinutes 20 -ImageCount 20

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

        $Schedule = New-ImageViewerFigureDrawSchedule -TotalMinutes 20 -ImageCount 6

        $Schedule.PoseCount | Should -Be 6
        $Schedule.Limiter | Should -Be 'Images'
        $Schedule.RemainingSeconds | Should -BeGreaterThan 0
    }

    It 'Uses F6 to toggle figure drawing mode through the time-based prompt flow' {
        $DslPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/ImageViewer.DSL.ps1'
        $DslContent = Get-Content -Path $DslPath -Raw

        $TogglePath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Invoke-ImageViewerToggleFigureDrawingMode.ps1'
        $ToggleContent = Get-Content -Path $TogglePath -Raw

        $DslContent | Should -Match 'Invoke-ImageViewerToggleFigureDrawingMode'
        $ToggleContent | Should -Match 'Enter figure drawing session minutes \(1 to 600\)'
        $ToggleContent | Should -Match 'Start-ImageViewerFigureDrawingMode\s+-TotalMinutes'
    }
}
