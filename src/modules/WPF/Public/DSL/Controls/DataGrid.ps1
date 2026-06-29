<#
.SYNOPSIS
    Creates a WPF DataGrid object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -DataGrid 'MyGrid' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.datagrid
#>
function DataGrid {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-DataGrid')]
    [OutputType([void], [System.Windows.Controls.DataGrid])]
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
        $DataGrid = [System.Windows.Controls.DataGrid]::new()
        if ($Name -ne '__Nameless__') {
            $DataGrid.Name = $Name
            Register-WPFObject $Name $DataGrid
        }
        Add-WPFType $DataGrid 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DataGrid) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $DataGrid.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (DataGrid)"
        Update-WPFObject $Parent $DataGrid
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DataGrid)"
    Update-WPFObject $DataGrid $ScriptBlock

    $IsParentedAfter = [bool] $DataGrid.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $DataGrid
    }
}
