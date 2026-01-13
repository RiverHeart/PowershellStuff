<#
.SYNOPSIS
    Updates a WPF object depending on the values returned
    with its' scriptblock.

.DESCRIPTION
    Updates a WPF object depending on the values returned
    with its' scriptblock.

    Intended to reduce code duplication for common operations
    like modifying object properties and adding handlers.

    Can return each result for further processing by the calling
    function.

.NOTES
    This function is only intended to be called by controls.
#>
function Update-WPFObject {
    [CmdletBinding(DefaultParameterSetName='ByScriptBlock')]
    [OutputType([void], [object[]])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=0)]
        [Parameter(Mandatory,ParameterSetName='ByChildObject',Position=0)]
        [object] $InputObject,

        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=1)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory,ParameterSetName='ByChildObject',Position=1)]
        [object[]] $ChildObjects,

        # Allow caller to get results for custom updates
        # without having to rerun the scriptblock
        [switch] $PassThru
    )

    $SelfName = if ($InputObject.Name) { $InputObject.Name } else { '<Nameless>' }
    $SelfType = $InputObject.GetType().Name

    $RowIndex = 0

    # Set `$self` as reference to the current object.
    # `$this` would be more idiomatic but this avoids
    # potential issues arising from modifying automatic variables.
    $PSVars = @(
        [psvariable]::new('self', $InputObject)
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
            $ChildObjects = $ScriptBlock.InvokeWithContext($null, $PSVars)
        }

        foreach ($Child in $ChildObjects) {
            $ChildName = if ($Child.Name) { $Child.Name } else { '<Nameless>' }
            $ChildType = $Child.GetType().Name

            # Returning objects early so I don't need to worry about breaking out
            # of a nested if statement later. Calling `continue` is much simpler.
            if ($PassThru) {
                Write-Output $Child
            }

            # Handler
            if (Test-WPFType $Child 'Handler') {
                # TODO: Wrap the scriptblock to catch errors and report them properly.
                Write-Debug "Adding handler for event '$($Child.event)' to object '$SelfName' ($SelfType)"
                $InputObject."Add_$($Child.Event)"($Child.ScriptBlock)

            # Command
            } elseif (Test-WPFType $Child 'Command') {
                Write-Debug "Adding Command to object '$SelfName' ($SelfType)"
                $InputObject.Command = $Child

            # Control
            } elseif (Test-WPFType $Child 'Control') {
                # Uses `PassThru` to send child objects further up the chain to get
                # processed by the Grid itself.
                if (Test-WPFType $InputObject 'GridDefinition') {
                    continue
                }

                if ($InputObject -eq $Child.Parent) {
                    Write-Debug "$SelfName ($SelfType) is already a parent of '$ChildName' ($ChildType)"
                    continue
                }

                if ($Child.Parent) {
                    Write-Debug "Removing child object '$ChildName' ($ChildType) from '$($Child.Parent.Name)' $($Child.Parent.GetType().Name))"
                    $Child.Parent.RemoveChild($Child)
                }

                Write-Debug "Adding child object '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
                $InputObject.AddChild($Child)

                # Hacky but what's a guy to do?
                $IsMenuBar =
                    $InputObject -is [System.Windows.Controls.DockPanel] -and
                    $Child -is [System.Windows.Controls.Menu]

                if ($IsMenuBar) {
                    [System.Windows.Controls.DockPanel]::SetDock($Child, [System.Windows.Controls.Dock]::Top)
                }

            # Shape
            } elseif (Test-WPFType $Child 'Shape') {
                # My thinking here is that while a user can assign a Path to a button's content
                # property other objects are probably assigned differently so it's just be easier
                # to add them based on the object type so you don't need to remember.
                if ($InputObject -is [System.Windows.Controls.Button]) {
                    $InputObject.Content = $Child
                }

            # GridRow
            } elseif (Test-WPFType $Child 'GridDefinition') {

                if ($InputObject -isnot [System.Windows.Controls.Grid]) {
                    # Move on. Rows and columns are processed by Grids and nothing else.
                    continue
                }

                $ColumnIndex = 0  # Track columns for each row
                $RowIndex++

                # Add row definitions as required. They may have been
                # initialized with the grid through explicit parameters.
                if ($InputObject.RowDefinitions.Count -lt $RowIndex) {
                    $InputObject.RowDefinitions.Add($Child)
                }

                # Process columns
                foreach ($Column in $Child.Children) {
                    $ColumnIndex++

                    # Add column definitions as required. They may have been
                    # initialized with the grid through explicit parameters.
                    if ($InputObject.ColumnDefinitions.Count -lt $ColumnIndex) {
                        $InputObject.ColumnDefinitions.Add($Column)
                    }

                    # Set Row/Column properties on child object,
                    # then add it as a child object.
                    foreach ($ColumnChild in $Column.Children) {
                        [System.Windows.Controls.Grid]::SetRow($ColumnChild, ($RowIndex - 1))
                        [System.Windows.Controls.Grid]::SetColumn($ColumnChild, ($ColumnIndex - 1))
                        $InputObject.AddChild($ColumnChild)
                    }
                }
            } else {
                # Maybe instead of erroring we just pass unhandled items further up the chain?
                Write-Warning "Cannot add '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
            }
        }
    } catch {
        Write-Error "Failed to update '$SelfName' ($SelfType) with error: $_"
        return
    }
}
