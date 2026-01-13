<#
.SYNOPSIS
    Creates a MenuBar by wrapping Menu in a DockPanel

.NOTES
    Use of the DockPanel is an implementation detail that is
    probably uninteresting to most users so this abstraction
    let's them ignore it.
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

    # Create an Menu wrapped in a DockPanel
    # Uses `GetNewClosure()` to ensure Name/Scriptblock variables
    # set here are unchanged when executed downstream
    $WPFObject = New-WPFDockPanel "${Name}_DockPanel" {
        New-WPFMenu $Name $ScriptBlock
    }.GetNewClosure()
    return $WPFObject
}
