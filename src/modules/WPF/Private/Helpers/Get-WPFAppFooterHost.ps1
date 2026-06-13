<#
.SYNOPSIS
    Returns the App footer host for a Window.

.DESCRIPTION
    Looks up the App footer host stored on the window's `_WPFAppFooter`
    property and returns it as a StackPanel when present.
#>
function Get-WPFAppFooterHost {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.StackPanel])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window] $Window
    )

    $FooterProperty = $Window.PSObject.Properties['_WPFAppFooter']
    if ($FooterProperty -and $FooterProperty.Value) {
        return [System.Windows.Controls.StackPanel] $FooterProperty.Value
    }

    return $null
}
