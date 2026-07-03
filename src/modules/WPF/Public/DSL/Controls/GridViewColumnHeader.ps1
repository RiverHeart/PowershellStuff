<#
.SYNOPSIS
    Creates a WPF GridViewColumnHeader object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -GridViewColumnHeader 'MyGridViewColumnHeader' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.gridviewcolumnheader
#>
function GridViewColumnHeader {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-GridViewColumnHeader')]
    [OutputType([void], [System.Windows.Controls.GridViewColumnHeader])]
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
        $GridViewColumnHeader = [System.Windows.Controls.GridViewColumnHeader]::new()
        if ($Name -ne '__Nameless__') {
            $GridViewColumnHeader.Name = $Name
            Register-WPFObject $Name $GridViewColumnHeader
        }
        Add-WPFType $GridViewColumnHeader 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (GridViewColumnHeader) with error: $_"
    }

    # Auto-attach self to parent if one exists.
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (GridViewColumnHeader)"
        Update-WPFObject $Parent $GridViewColumnHeader
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (GridViewColumnHeader)"
    Update-WPFObject $GridViewColumnHeader $ScriptBlock

    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $Parent) {
        return $GridViewColumnHeader
    }
}
