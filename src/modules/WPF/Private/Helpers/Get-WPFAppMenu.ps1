<#
.SYNOPSIS
    Gets or creates the implicit App menu for a Window.

.DESCRIPTION
    Returns a cached menu when available. If one does not exist, it creates a
    menu, registers it in the window context, attaches it to the App root, and
    caches it on the window object.
#>
function Get-WPFAppMenu {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Menu])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window] $Window
    )

    $CachedMenu = $Window.PSObject.Properties['_WPFAppMenu']
    if ($CachedMenu -and $CachedMenu.Value) {
        return $CachedMenu.Value
    }

    $RootProperty = $Window.PSObject.Properties['_WPFAppRoot']
    if (-not $RootProperty -or -not $RootProperty.Value) {
        return $null
    }

    $Root = [System.Windows.Controls.DockPanel] $RootProperty.Value
    $ExistingMenu = @(
        $Root.Children |
            Where-Object { $_ -is [System.Windows.Controls.Menu] } |
            Select-Object -First 1
    )
    if ($ExistingMenu.Count -gt 0) {
        $Menu = [System.Windows.Controls.Menu] $ExistingMenu[0]
        $Window | Add-Member -NotePropertyName '_WPFAppMenu' -NotePropertyValue $Menu -Force
        return $Menu
    }

    $ContextId = Get-WPFControlContextId -InputObject $Window
    $MenuName = if ($Window.Name) { "__{0}Menu" -f $Window.Name } else { '__AppMenu' }
    $Menu = [System.Windows.Controls.Menu] @{
        Name = $MenuName
    }

    Register-WPFObject -Name $MenuName -InputObject $Menu -ContextId $ContextId
    Add-WPFType $Menu 'Control'
    Add-WPFAppRootChild -Window $Window -Child $Menu -Placement 'Menu'

    $Window | Add-Member -NotePropertyName '_WPFAppMenu' -NotePropertyValue $Menu -Force

    return $Menu
}
