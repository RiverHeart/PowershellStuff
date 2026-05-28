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

        $Content | Should -Match "'Left'\s*\{\s*if \(Test-ImageViewerShouldNavigate\)"
        $Content | Should -Match "'Space'\) \} \{\s*if \(\$event.Key -eq \[Key\]::Space -or \(Test-ImageViewerShouldNavigate\)\)"

        $HelperPath = Join-Path $PSScriptRoot '../Examples/ImageViewer/functions/Test-ImageViewerShouldNavigate.ps1'
        $HelperContent = Get-Content -Path $HelperPath -Raw

        $HelperContent | Should -Match 'IsKeyboardFocusWithin'
        $HelperContent | Should -Match 'ScrollableWidth'
        $HelperContent | Should -Not -Match 'HorizontalOffset'
    }
}
