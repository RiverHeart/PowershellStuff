<#
.SYNOPSIS
    Creates a WPF TreeViewItem object.

.DESCRIPTION
    Creates a TreeViewItem and attempts to auto-attach to a parent `TreeView`
    or `TreeViewItem` if one exists. Set `$this.Header` to control the
    displayed text and nest further `TreeViewItem` blocks to build hierarchy.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -TreeViewItem 'MyItem' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.treeviewitem
#>
function TreeViewItem {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-TreeViewItem')]
    [OutputType([void], [System.Windows.Controls.TreeViewItem])]
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
        $TreeViewItem = [System.Windows.Controls.TreeViewItem]::new()
        if ($Name -ne '__Nameless__') {
            $TreeViewItem.Name = $Name
            Register-WPFObject $Name $TreeViewItem
        }
        Add-WPFType $TreeViewItem 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TreeViewItem) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $TreeViewItem.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (TreeViewItem)"
        Update-WPFObject $Parent $TreeViewItem
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TreeViewItem)"
    Update-WPFObject $TreeViewItem $ScriptBlock

    $IsParentedAfter = [bool] $TreeViewItem.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $TreeViewItem
    }
}
