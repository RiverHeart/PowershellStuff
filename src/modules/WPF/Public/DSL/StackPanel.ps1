<#
.SYNOPSIS
    Creates a WPF StackPanel object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.stackpanel
#>
function StackPanel {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.StackPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $StackPanel = [System.Windows.Controls.StackPanel] @{
            Name = $Name
        }
        Register-WPFObject $Name $StackPanel
        Add-WPFType $StackPanel 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StackPanel) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if (-not $NoAutoAttach -and $Parent -and -not $StackPanel.Parent) {
        Write-Debug "Beginning auto-attach for $Name (StackPanel)"
        Update-WPFObject $Parent $StackPanel
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (StackPanel)"
    Update-WPFObject $StackPanel $ScriptBlock

    if ($this.Parent) { return }
    return $StackPanel
}
