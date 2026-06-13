<#
.SYNOPSIS
    Adds a child object to the App shell in the requested region.

.DESCRIPTION
    Routes controls into the App root shell using placement semantics:
    Menu (top), Footer (bottom above the status bar), StatusBar (bottom), or
    Content (main content host).
#>
function Add-WPFAppRootChild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window] $Window,

        [Parameter(Mandatory)]
        [object] $Child,

        [Parameter(Mandatory)]
        [ValidateSet('Menu', 'Footer', 'StatusBar', 'Content')]
        [string] $Placement
    )

    $RootProperty = $Window.PSObject.Properties['_WPFAppRoot']
    $ContentProperty = $Window.PSObject.Properties['_WPFAppContent']

    if (-not $RootProperty -or -not $RootProperty.Value -or
        -not $ContentProperty -or -not $ContentProperty.Value
    ) {
        return
    }

    $Root = [System.Windows.Controls.DockPanel] $RootProperty.Value
    $ContentHost = [System.Windows.Controls.Grid] $ContentProperty.Value

    if ($Placement -eq 'Content') {
        if ($Child -eq $ContentHost) {
            Add-WPFObject $Root $Child
        } else {
            Add-WPFObject $ContentHost $Child
        }
        return
    }

    if ($Child.Parent -and ($Child.Parent -ne $Root)) {
        $Child.Parent.RemoveChild($Child)
    } elseif ($Child.Parent -eq $Root) {
        $Root.Children.Remove($Child)
    }

    switch ($Placement) {
        'Menu' {
            [System.Windows.Controls.DockPanel]::SetDock($Child, [System.Windows.Controls.Dock]::Top)
            $InsertIndex = 0
        }
        'Footer' {
            [System.Windows.Controls.DockPanel]::SetDock($Child, [System.Windows.Controls.Dock]::Bottom)
            $InsertIndex = @($Root.Children | Where-Object {
                $_ -is [System.Windows.Controls.Menu] -or
                $_ -is [System.Windows.Controls.Primitives.StatusBar]
            }).Count
        }
        'StatusBar' {
            [System.Windows.Controls.DockPanel]::SetDock($Child, [System.Windows.Controls.Dock]::Bottom)
            $InsertIndex = @($Root.Children | Where-Object {
                $_ -is [System.Windows.Controls.Menu]
            }).Count
        }
    }

    $ContentIndex = $Root.Children.IndexOf($ContentHost)
    if ($ContentIndex -ge 0 -and $InsertIndex -ge $ContentIndex) {
        $InsertIndex = $ContentIndex
    }

    $Root.Children.Insert($InsertIndex, $Child)
}
