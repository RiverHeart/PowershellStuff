function Add-WPFObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [object[]] $ChildObjects
    )

    $SelfName = if ($InputObject.Name) { $InputObject.Name } else { '<Nameless>' }
    $SelfType = $InputObject.GetType().Name

    foreach($Child in $ChildObjects) {
        $ChildName = if ($Child.Name) { $Child.Name } else { '<Nameless>' }
        $ChildType = $Child.GetType().Name

        # Ignore if object is correctly parented
        if ($InputObject -eq $Child.Parent) {
            Write-Debug "$SelfName ($SelfType) is already a parent of '$ChildName' ($ChildType)"
            continue
        }

        # If object has incorrect parent, unattach child
        if ($Child.Parent) {
            Write-Debug "Removing child object '$ChildName' ($ChildType) from '$($Child.Parent.Name)' $($Child.Parent.GetType().Name))"
            $Child.Parent.RemoveChild($Child)
        }

        # NOTE: This is extremely problematic because the old way
        # was keeping track of the number of columns per row whereas
        # this is not and ends up creating a column for every column
        # in every row...
        #
        # Really, I need to have the Grid or Rows keep track of
        # how many columns they have so I know what the whether they
        # need added or not.
        if ($InputObject -is [System.Windows.Controls.Grid] -and
            $Child -is [System.Windows.Controls.RowDefinition]
        ) {
            $InputObject.RowDefinitions.Add($Child)
        }
        elseif (
            $InputObject -is [System.Windows.Controls.Grid] -or
            $InputObject -is [System.Windows.Controls.RowDefinition] -and
            $Child -is [System.Windows.Controls.ColumnDefinition]
        ) {
            if ($InputObject -is [System.Windows.Controls.Grid]) {
                $InputObject.ColumnDefinitions.Add($Child)
            } else {
                $InputObject.AddColumn($Child)
            }
        }
        elseif (
            $Child -is [System.Windows.Controls.RowDefinition] -or
            $Child -is [System.Windows.Controls.ColumnDefinition]
        ) {
            Write-Error "Cannot add '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
            return
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
