function Add-WPFObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [object[]] $ChildObjects
    )

    $SelfName = if ($InputObject.Name) { $InputObject.Name } else { '__Nameless__' }
    $SelfType = $InputObject.GetType().Name

    foreach($Child in $ChildObjects) {
        $ChildName = if ($Child.Name) { $Child.Name } else { '__Nameless__' }
        $ChildType = $Child.GetType().Name
        $ChildParentProperty = $Child.PSObject.Properties['Parent']
        $ChildParent = if ($ChildParentProperty) { $Child.Parent } else { $null }

        # Ignore if object is correctly parented
        if ($ChildParentProperty -and $InputObject -eq $ChildParent) {
            Write-Debug "$SelfName ($SelfType) is already a parent of '$ChildName' ($ChildType)"
            continue
        } elseif ($ChildParentProperty -and $ChildParent -and ($ChildParent -ne $InputObject)) {
            # If child has incorrect parent, unattach child.{
            Write-Debug "Removing child object '$ChildName' ($ChildType) from '$($ChildParent.Name)' $($ChildParent.GetType().Name))"
            if ($ChildParent.PSObject.Methods['RemoveChild']) {
                $ChildParent.RemoveChild($Child)
            }
        }

        # FrameworkElementFactory tree: factories attach to other factories or to ControlTemplate.
        if ($InputObject -is [System.Windows.FrameworkElementFactory]) {
            Write-Debug "AppendChild: '$ChildName' ($ChildType) -> factory '$SelfName'"
            $InputObject.AppendChild($Child)
            continue
        }
        elseif ($InputObject -is [System.Windows.Controls.ControlTemplate] -and
            $Child -is [System.Windows.FrameworkElementFactory]
        ) {
            Write-Debug "Setting VisualTree: '$ChildName' ($ChildType) -> ControlTemplate"
            $InputObject.VisualTree = $Child
            continue
        }
        elseif (
            $InputObject -is [System.Windows.Controls.DataGrid] -and
            $Child -is [System.Windows.Controls.DataGridColumn]
        ) {
            if ($InputObject.Columns.IndexOf($Child) -ge 0) {
                Write-Warning "Duplicate DataGridColumn add prevented for '$ChildName' ($ChildType) on '$SelfName' ($SelfType). This usually indicates a child-collection scope leak."
                continue
            }

            Write-Debug "Adding DataGridColumn '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
            $InputObject.Columns.Add($Child)
            continue
        }
        elseif (
            $InputObject -is [System.Windows.Controls.ListView] -and
            $Child -is [System.Windows.Controls.GridView]
        ) {
            Write-Debug "Setting ListView view '$ChildName' ($ChildType) on '$SelfName' ($SelfType)"
            $InputObject.View = $Child
            continue
        }
        elseif (
            $InputObject -is [System.Windows.Controls.GridView] -and
            $Child -is [System.Windows.Controls.GridViewColumn]
        ) {
            if ($InputObject.Columns.IndexOf($Child) -ge 0) {
                Write-Warning "Duplicate GridViewColumn add prevented for '$ChildName' ($ChildType) on '$SelfName' ($SelfType). This usually indicates a child-collection scope leak."
                continue
            }

            Write-Debug "Adding GridViewColumn '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
            $InputObject.Columns.Add($Child)
            continue
        }
        elseif (
            $InputObject -is [System.Windows.Controls.GridViewColumn] -and
            $Child -is [System.Windows.Controls.GridViewColumnHeader]
        ) {
            Write-Debug "Setting GridViewColumn header '$ChildName' ($ChildType) on '$SelfName' ($SelfType)"
            $InputObject.Header = $Child
            continue
        }
        # Special handling for adding GridDefinitions to Grid.
        # GridDefinitions given `AddChild()` methods so they behave
        # the same as controls.
        if ($InputObject -is [System.Windows.Controls.Grid] -and
            $Child -is [System.Windows.Controls.RowDefinition]
        ) {
            $InputObject.RowDefinitions.Add($Child)
        }
        elseif (
            $InputObject -is [System.Windows.Controls.Grid] -and
            $Child -is [System.Windows.Controls.ColumnDefinition]
        ) {
            $InputObject.ColumnDefinitions.Add($Child)
        }
        else {
            Write-Debug "Adding child object '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
            $InputObject.AddChild($Child)
        }

        # Hacky but what's a guy to do?
        # TODO: Find a better way
        $IsMenuBar =
            $InputObject -is [System.Windows.Controls.DockPanel] -and
            $Child -is [System.Windows.Controls.Menu]

        if ($IsMenuBar) {
            [System.Windows.Controls.DockPanel]::SetDock($Child, [System.Windows.Controls.Dock]::Top)
        }
    }
}
