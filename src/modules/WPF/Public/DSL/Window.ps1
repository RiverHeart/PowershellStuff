<#
.SYNOPSIS
    Creates a WPF Window object.

.DESCRIPTION
    Creates a WPF Window object. Window is always treated as a root element
    and will never auto-attach to a parent. Use the Owner property to establish
    an owner relationship for modal dialogs.

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

    # Window is always root; do not auto-attach to parent
    # Use the Owner property to establish ownership relationships

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Window)"
    Update-WPFObject $Window $ScriptBlock

    return $Window
}
