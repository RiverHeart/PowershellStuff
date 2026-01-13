<#
.SYNOPSIS
    Creates a MenuBar by wrapping Menu in a DockPanel

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.dockpanel
#>
function New-WPFMenuBar {
    [Alias('MenuBar')]
    [OutputType([System.Windows.Controls.DockPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    $WPFObject = New-WPFDockPanel "${Name}_DockPanel" {
        New-WPFMenu $Name $ScriptBlock
    }.GetNewClosure()
    return $WPFObject
}
