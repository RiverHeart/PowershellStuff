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
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Grid')]
    [OutputType([void], [System.Windows.Controls.Grid])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Grid = [System.Windows.Controls.Grid]::new()
        $Grid | Add-Member -Name 'AllowPackedCells' -MemberType NoteProperty -Value $false -Force
        if ($Name -ne '__Nameless__') {
            $Grid.Name = $Name
            Register-WPFObject $Name $Grid
        }
        Add-WPFType $Grid 'Control'
        Add-WPFType $Grid 'CollectorOwner'
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
            Write-Debug "[Row=$RowIndex] Skipping null row"
            continue
        }

        if ('WPF.Grid.RowSpec' -notin $Row.PSTypeNames) {
            throw "Grid rows must be declared with Row { ... }"
        }

        if ($Grid.RowDefinitions.Count -le $RowIndex) {
            Write-Debug "[Row=$RowIndex] Adding row definition"
            $Grid.RowDefinitions.Add((New-WPFGridRow -Height $Row.Height))
        }

        $Columns = @($Row.Columns)
        for ($ColumnIndex = 0; $ColumnIndex -lt $Columns.Count; $ColumnIndex++) {
            Write-Debug "[Row=$RowIndex Column=$ColumnIndex] Processing column"

            $Column = $Columns[$ColumnIndex]
            if ($null -eq $Column) {
                Write-Debug "[Row=$RowIndex Column=$ColumnIndex] Skipping null column"
                continue
            }

            if ('WPF.Grid.ColumnSpec' -notin $Column.PSTypeNames) {
                throw "Grid columns must be declared with Column { ... }"
            }

            if ($Grid.ColumnDefinitions.Count -le $ColumnIndex) {
                Write-Debug "[Row=$RowIndex Column=$ColumnIndex] Adding column definition"
                $Grid.ColumnDefinitions.Add((New-WPFGridColumn -Width $Column.Width))
            }

            foreach ($Child in @($Column.Children)) {
                if ($null -eq $Child) {
                    continue
                }
                $ChildName = if ($Child.Name) { $Child.Name } else { '__Nameless__' }
                $ChildType = $Child.GetType().Name

                Write-Debug "[Row=$RowIndex Column=$ColumnIndex] Setting child '$ChildName' ($ChildType) position"
                [System.Windows.Controls.Grid]::SetRow($Child, $RowIndex)
                [System.Windows.Controls.Grid]::SetColumn($Child, $ColumnIndex)
            }
        }
    }

    if ($Grid.Parent) { return }
    return $Grid
}
