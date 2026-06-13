function Invoke-ImageViewerToggleTheme {
    [CmdletBinding()]
    param()

    $Window = Get-WPFWindow
    Switch-WPFTheme -Root $Window
}
