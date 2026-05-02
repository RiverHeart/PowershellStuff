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

        # Ignore if object is correctly parented
        if ($InputObject -eq $Child.Parent) {
            Write-Debug "$SelfName ($SelfType) is already a parent of '$ChildName' ($ChildType)"
            continue
        } elseif ($Child.Parent -and ($Child.Parent -ne $InputObject)) {
            # If child has incorrect parent, unattach child.{
            Write-Debug "Removing child object '$ChildName' ($ChildType) from '$($Child.Parent.Name)' $($Child.Parent.GetType().Name))"
            $Child.Parent.RemoveChild($Child)
        }

        # FrameworkElementFactory tree: factories attach to other factories or to ControlTemplate.
        if ($InputObject -is [System.Windows.FrameworkElementFactory]) {
            Write-Debug "AppendChild: '$ChildName' ($ChildType) -> factory '$SelfName'"
            $InputObject.AppendChild($Child)
        }
        elseif ($InputObject -is [System.Windows.Controls.ControlTemplate] -and
            $Child -is [System.Windows.FrameworkElementFactory]
        ) {
            Write-Debug "Setting VisualTree: '$ChildName' ($ChildType) -> ControlTemplate"
            $InputObject.VisualTree = $Child
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
