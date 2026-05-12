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
    [CmdletBinding()]
    [Alias('-DataGrid')]
    [OutputType([void], [System.Windows.Controls.DataGrid])]
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
        $DataGrid = [System.Windows.Controls.DataGrid] @{
            Name = $Name
        }
        Register-WPFObject $Name $DataGrid
        Add-WPFType $DataGrid 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DataGrid) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (DataGrid)"
        Update-WPFObject $Parent $DataGrid
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DataGrid)"
    Update-WPFObject $DataGrid $ScriptBlock

    if ($this.Parent) { return }
    return $DataGrid
}
