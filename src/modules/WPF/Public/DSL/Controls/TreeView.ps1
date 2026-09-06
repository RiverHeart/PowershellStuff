<#
.SYNOPSIS
    Creates a WPF TreeView object.

.DESCRIPTION
    Creates a TreeView, registers it in the current context, and attempts to
    auto-attach to a parent if one exists. Nested `TreeViewItem` blocks are
    added to the `Items` collection.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -TreeView 'MyTreeView' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.treeview
#>
function TreeView {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-TreeView')]
    [OutputType([void], [System.Windows.Controls.TreeView])]
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
        $TreeView = [System.Windows.Controls.TreeView]::new()
        if ($Name -ne '__Nameless__') {
            $TreeView.Name = $Name
            Register-WPFObject $Name $TreeView
        }
        Add-WPFType $TreeView 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TreeView) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $TreeView.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (TreeView)"
        Update-WPFObject $Parent $TreeView
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TreeView)"
    Update-WPFObject $TreeView $ScriptBlock

    $IsParentedAfter = [bool] $TreeView.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $TreeView
    }
}
