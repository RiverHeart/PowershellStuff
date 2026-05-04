function Invoke-ImageViewerToggleTheme {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    Switch-WPFTheme -Root $Window
    Update-ImageViewerIcon -PanelName 'ButtonPanel'
}
