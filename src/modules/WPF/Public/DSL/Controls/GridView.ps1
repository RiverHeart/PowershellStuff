<#
.SYNOPSIS
    Creates a WPF GridView object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -GridView 'MyGridView' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.gridview
#>
function GridView {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-GridView')]
    [OutputType([void], [System.Windows.Controls.GridView])]
    param (
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
        $GridView = [System.Windows.Controls.GridView]::new()
        if ($Name -ne '__Nameless__') {
            Register-WPFObject $Name $GridView
        }
        Add-WPFType $GridView 'ListViewView'
    } catch {
        Write-Error "Failed to create '$Name' (GridView) with error: $_"
        return
    }

    # Auto-attach self to parent if one exists.
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (GridView)"
        Update-WPFObject $Parent $GridView
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (GridView)"
    Update-WPFObject $GridView $ScriptBlock

    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $Parent) {
        return $GridView
    }
}
