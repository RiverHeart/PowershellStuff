<#
.SYNOPSIS
    Creates a WPF DockPanel object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.dockpanel
#>
function New-WPFDockPanel {
    [Alias('DockPanel')]
    [OutputType([System.Windows.Controls.DockPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock,

        [switch] $NoAutoAttach
    )

    try {
        $WPFObject = [System.Windows.Controls.DockPanel] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DockPanel) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Write-Debug "Beginning auto-attach for $Name (DockPanel)"
        Update-WPFObject $Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DockPanel)"
    Update-WPFObject $WPFObject $ScriptBlock

    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
