<#
.SYNOPSIS
    Returns the App content host for a Window.

.DESCRIPTION
    Looks up the App content host stored on the window's `_WPFAppContent`
    property and returns it as a Grid when present.
#>
function Get-WPFAppContentHost {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Grid])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window] $Window
    )

    $ContentProperty = $Window.PSObject.Properties['_WPFAppContent']
    if ($ContentProperty -and $ContentProperty.Value) {
        return [System.Windows.Controls.Grid] $ContentProperty.Value
    }

    return $null
}
