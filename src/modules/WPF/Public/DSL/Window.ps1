<#
.SYNOPSIS
    Creates a WPF Window object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.window
#>
function Window {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $Window = [System.Windows.Window] @{
            Name = $Name
        }
        Register-WPFObject $Name $Window
        if (-not $Window.Height -and -not $Window.Width){
            $Window.SizeToContent = 'WidthAndHeight'
        }
        Add-WPFType $Window 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Window) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (Window)"
        Update-WPFObject $Parent $Window
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Window)"
    Update-WPFObject $Window $ScriptBlock

    if ($this.Parent) { return }
    return $Window
}
