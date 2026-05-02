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
    [CmdletBinding()]
    [Alias('-DockPanel')]
    [OutputType([void], [System.Windows.Controls.DockPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $DockPanel = [System.Windows.Controls.DockPanel] @{
            Name = $Name
        }
        Register-WPFObject $Name $DockPanel
        Add-WPFType $DockPanel 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DockPanel) with error: $_"
    }

    # Auto-attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (DockPanel)"
        Update-WPFObject $Parent $DockPanel
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DockPanel)"
    Update-WPFObject $DockPanel $ScriptBlock

    if ($this.Parent) { return }
    return $DockPanel
}
