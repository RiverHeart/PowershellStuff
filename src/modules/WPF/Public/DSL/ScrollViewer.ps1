<#
.SYNOPSIS
    Creates a WPF ScrollViewer object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.scrollviewer
#>
function ScrollViewer {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.ScrollViewer])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $ScrollViewer = [System.Windows.Controls.ScrollViewer] @{
            Name = $Name
        }
        Register-WPFObject $Name $ScrollViewer
        Add-WPFType $ScrollViewer 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ScrollViewer) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (ScrollViewer)"
        Update-WPFObject $Parent $ScrollViewer
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (ScrollViewer)"
    Update-WPFObject $ScrollViewer $ScriptBlock

    if ($this.Parent) { return }
    return $ScrollViewer
}
