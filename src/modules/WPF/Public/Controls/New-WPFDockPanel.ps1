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
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.DockPanel] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Update-WPFObject $WPFObject $ScriptBlock
        Set-WPFObjectType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DockPanel) with error: $_"
    }
    return $WPFObject
}
