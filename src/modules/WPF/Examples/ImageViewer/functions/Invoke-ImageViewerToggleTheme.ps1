function Invoke-ImageViewerToggleTheme {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    Toggle-WPFTheme -Root $Window
    Invoke-ImageViewerUpdateNavigationIconStyle
}
