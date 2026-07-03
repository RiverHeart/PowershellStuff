<#
.SYNOPSIS
    Creates a WPF ListView object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -ListView 'MyListView' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.listview
#>
function ListView {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-ListView')]
    [OutputType([void], [System.Windows.Controls.ListView])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ -not ($_ -is [scriptblock]) })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $ListView = [System.Windows.Controls.ListView]::new()
        if ($Name -ne '__Nameless__') {
            $ListView.Name = $Name
            Register-WPFObject $Name $ListView
        }
        Add-WPFType $ListView 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ListView) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $ListView.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (ListView)"
        Update-WPFObject $Parent $ListView
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (ListView)"
    Update-WPFObject $ListView $ScriptBlock

    $IsParentedAfter = [bool] $ListView.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $ListView
    }
}
