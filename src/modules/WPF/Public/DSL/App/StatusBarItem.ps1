<#
.SYNOPSIS
    Creates a WPF StatusBarItem object.

.DESCRIPTION
    Supports both named and nameless forms:

    StatusBarItem 'ZoomHost' { ... }
    StatusBarItem { ... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.primitives.statusbaritem
#>
function StatusBarItem {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-StatusBarItem')]
    [OutputType([void], [System.Windows.Controls.Primitives.StatusBarItem])]
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
        $StatusBarItem = [System.Windows.Controls.Primitives.StatusBarItem]::new()
        if ($Name -ne '__Nameless__') {
            $StatusBarItem.Name = $Name
            Register-WPFObject $Name $StatusBarItem
        }
        Add-WPFType $StatusBarItem 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StatusBarItem) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $StatusBarItem.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (StatusBarItem)"
        Update-WPFObject $Parent $StatusBarItem
    }

    Write-Debug "Processing child elements for $Name (StatusBarItem)"
    Update-WPFObject $StatusBarItem $ScriptBlock

    $IsParentedAfter = [bool] $StatusBarItem.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $StatusBarItem
    }
}
