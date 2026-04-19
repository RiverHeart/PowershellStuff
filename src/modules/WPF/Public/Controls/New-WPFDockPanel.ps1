<#
.SYNOPSIS
    Creates a WPF DockPanel object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.dockpanel
#>
function New-WPFDockPanel {
    [OutputType([System.Windows.Controls.DockPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
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

    return $WPFObject
}
