<#
.SYNOPSIS
    Keyword for defining a WPF Grid

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.grid
#>
function Grid {
    [OutputType([System.Windows.Controls.Grid])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $Grid = [System.Windows.Controls.Grid] @{
            Name = $Name
        }
        Register-WPFObject $Name $Grid
        Add-WPFType $Grid 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Grid) with error: $_"
    }

    $PSVars = @([psvariable]::new('this', $Parent))

    foreach($Row in $ScriptBlock.InvokeWithContext($null, $PSVars)) {

        $ColumnIndex = 0  # Track columns for each row
        $RowIndex++

        # Add row definitions as required. They may have been
        # initialized with the grid through explicit parameters.
        if ($Grid.RowDefinitions.Count -lt $RowIndex) {
            $Grid.RowDefinitions.Add((New-WPFGridRow))
        }

        # Process columns
        foreach ($Column in $Row) {
            $ColumnIndex++

            # Add column definitions as required. They may have been
            # initialized with the grid through explicit parameters.
            if ($Grid.ColumnDefinitions.Count -lt $ColumnIndex) {
                $Grid.ColumnDefinitions.Add((New-WPFGridColumn))
            }

            # Set Row/Column properties on child object,
            # then add it as a child object.
            foreach ($Child in $Column) {
                [System.Windows.Controls.Grid]::SetRow($Child, ($RowIndex - 1))
                [System.Windows.Controls.Grid]::SetColumn($Child, ($ColumnIndex - 1))
                $Grid.AddChild($Child)
            }
        }
    }

    return $Grid
}
