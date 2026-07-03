<#
.SYNOPSIS
    Creates a WPF GridViewColumn object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -GridViewColumn 'MyGridViewColumn' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.gridviewcolumn
#>
function GridViewColumn {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-GridViewColumn')]
    [OutputType([void], [System.Windows.Controls.GridViewColumn])]
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
        $GridViewColumn = [System.Windows.Controls.GridViewColumn]::new()
        if ($Name -ne '__Nameless__') {
            Register-WPFObject $Name $GridViewColumn
        }
        Add-WPFType $GridViewColumn 'GridViewColumn'
    } catch {
        Write-Error "Failed to create '$Name' (GridViewColumn) with error: $_"
        return
    }

    # Auto-attach self to parent if one exists.
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (GridViewColumn)"
        Update-WPFObject $Parent $GridViewColumn
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (GridViewColumn)"
    Update-WPFObject $GridViewColumn $ScriptBlock

    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $Parent) {
        return $GridViewColumn
    }
}
