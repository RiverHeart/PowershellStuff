<#
.SYNOPSIS
    Creates a WPF DockPanel object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -DockPanel 'MyPanel' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.dockpanel
#>
function DockPanel {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-DockPanel')]
    [OutputType([void], [System.Windows.Controls.DockPanel])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ -not ($_ -is [scriptblock]) })]
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
        $DockPanel = [System.Windows.Controls.DockPanel]::new()
        if ($Name -ne '__Nameless__') {
            $DockPanel.Name = $Name
            Register-WPFObject $Name $DockPanel
        }
        Add-WPFType $DockPanel 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DockPanel) with error: $_"
    }

    # Auto-attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $DockPanel.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (DockPanel)"
        Update-WPFObject $Parent $DockPanel
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DockPanel)"
    Update-WPFObject $DockPanel $ScriptBlock

    $IsParentedAfter = [bool] $DockPanel.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $DockPanel
    }
}
