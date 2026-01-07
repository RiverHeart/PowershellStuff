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
    [CmdletBinding()]
    [OutputType([void], [object[]])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

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
        foreach ($Result in $ScriptBlock.InvokeWithContext($null, $PSVars)) {
            $ChildName = if ($Result.Name) { $Result.Name } else { '<Nameless>' }
            $ChildType = $Result.GetType().Name

            # Returning objects early so I don't need to worry about breaking out
            # of a nested if statement later. Calling `continue` is much simpler.
            if ($PassThru) {
                Write-Output $Result
            }

            # Handler
            if (Test-WPFType $Result 'Handler') {
                # TODO: Wrap the scriptblock to catch errors and report them properly.
                Write-Debug "Adding handler for event '$($Result.event)' to object '$SelfName' ($SelfType)"
                $InputObject."Add_$($Result.Event)"($Result.ScriptBlock)

            # Command
            } elseif (Test-WPFType $Result 'Command') {
                Write-Debug "Adding Command to object '$SelfName' ($SelfType)"
                $InputObject.Command = $Result

            # Control
            } elseif (Test-WPFType $Result 'Control') {
                # Uses `PassThru` to send child objects further up the chain to get
                # processed by the Grid itself.
                if (Test-WPFType $InputObject 'GridDefinition') {
                    continue
                }

                Write-Debug "Adding child object '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
                $InputObject.AddChild($Result)

                # Hacky but what's a guy to do?
                $IsMenuBar =
                    $InputObject -is [System.Windows.Controls.DockPanel] -and
                    $Result -is [System.Windows.Controls.Menu]

                if ($IsMenuBar) {
                    [System.Windows.Controls.DockPanel]::SetDock($Result, [System.Windows.Controls.Dock]::Top)
                }

            # Shape
            } elseif (Test-WPFType $Result 'Shape') {
                # My thinking here is that while a user can assign a Path to a button's content
                # property other objects are probably assigned differently so it's just be easier
                # to add them based on the object type so you don't need to remember.
                if ($InputObject -is [System.Windows.Controls.Button]) {
                    $InputObject.Content = $Result
                }

            # GridRow
            } elseif (Test-WPFType $Result 'GridDefinition') {

                if ($InputObject -isnot [System.Windows.Controls.Grid]) {
                    # Move on. Rows and columns are processed by Grids and nothing else.
                    continue
                }

                $ColumnIndex = 0  # Track columns for each row
                $RowIndex++

                # Add row definitions as required. They may have been
                # initialized with the grid through explicit parameters.
                if ($InputObject.RowDefinitions.Count -lt $RowIndex) {
                    $InputObject.RowDefinitions.Add($Result)
                }

                # Process columns
                foreach ($Column in $Result.Children) {
                    $ColumnIndex++

                    # Add column definitions as required. They may have been
                    # initialized with the grid through explicit parameters.
                    if ($InputObject.ColumnDefinitions.Count -lt $ColumnIndex) {
                        $InputObject.ColumnDefinitions.Add($Column)
                    }

                    # Set Row/Column properties on child object,
                    # then add it as a child object.
                    foreach ($Child in $Column.Children) {
                        [System.Windows.Controls.Grid]::SetRow($Child, ($RowIndex - 1))
                        [System.Windows.Controls.Grid]::SetColumn($Child, ($ColumnIndex - 1))
                        $InputObject.AddChild($Child)
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
