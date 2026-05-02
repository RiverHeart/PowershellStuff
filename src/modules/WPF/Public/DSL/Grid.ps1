<#
.SYNOPSIS
    Keyword for defining a WPF Grid

.NOTES
    Grid behaves differently from most DSL controls because it has to infer
    layout structure before children can be positioned. WPF stores column
    definitions on the Grid itself rather than on individual rows, so the Grid
    tracks the widest row it has seen and only adds new column definitions when
    needed.

    Row and Column act as layout specifications instead of auto-attaching
    controls directly. They do not know their final row or column index until
    the Grid processes the full layout, so the Grid is responsible for assigning
    coordinates, growing row and column definitions, and attaching child
    controls in the correct position.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.grid
#>
function Grid {
    [CmdletBinding()]
    [Alias('-Grid')]
    [OutputType([void], [System.Windows.Controls.Grid])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Grid = [System.Windows.Controls.Grid] @{
            Name = $Name
        }
        Register-WPFObject $Name $Grid
        Add-WPFType $Grid 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Grid) with error: $_"
    }

    # Attach to parent if one exists so child controls can resolve hierarchy.
    $Parent = $PSCmdlet.GetVariableValue('this')
    if (-not $Parent) {
        $Parent = Get-Variable -Name 'this' -Scope 1 -ValueOnly -ErrorAction SilentlyContinue
    }
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (Grid)"
        Update-WPFObject $Parent $Grid
    }

    $PSVars = New-WPFVariableList -InputObject $Grid
    $Rows = @($ScriptBlock.InvokeWithContext($null, $PSVars))

    for ($RowIndex = 0; $RowIndex -lt $Rows.Count; $RowIndex++) {
        $Row = $Rows[$RowIndex]
        if ($null -eq $Row) {
            continue
        }

        if ('WPF.Grid.RowSpec' -notin $Row.PSTypeNames) {
            throw "Grid rows must be declared with Row { ... }"
        }

        if ($Grid.RowDefinitions.Count -le $RowIndex) {
            $Grid.RowDefinitions.Add((New-WPFGridRow -Height $Row.Height))
        }

        $Columns = @($Row.Columns)
        for ($ColumnIndex = 0; $ColumnIndex -lt $Columns.Count; $ColumnIndex++) {
            $Column = $Columns[$ColumnIndex]
            if ($null -eq $Column) {
                continue
            }

            if ('WPF.Grid.ColumnSpec' -notin $Column.PSTypeNames) {
                throw "Grid columns must be declared with Column { ... }"
            }

            if ($Grid.ColumnDefinitions.Count -le $ColumnIndex) {
                $Grid.ColumnDefinitions.Add((New-WPFGridColumn -Width $Column.Width))
            }

            foreach ($Child in @($Column.Children)) {
                if ($null -eq $Child) {
                    continue
                }

                [System.Windows.Controls.Grid]::SetRow($Child, $RowIndex)
                [System.Windows.Controls.Grid]::SetColumn($Child, $ColumnIndex)
                Add-WPFObject $Grid $Child
            }
        }
    }

    if ($Grid.Parent) { return }
    return $Grid
}
