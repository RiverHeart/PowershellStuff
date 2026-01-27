<#
.SYNOPSIS
    Creates a WPF Window object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.window
#>
function New-WPFWindow {
    [Alias('Window')]
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock,

        [switch] $NoAutoAttach
    )

    try {
        $WPFObject = [System.Windows.Window] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        if (-not $WPFObject.Height -and -not $WPFObject.Width){
            $WPFObject.SizeToContent = 'WidthAndHeight'
        }
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Window) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Write-Debug "Beginning auto-attach for $Name (Window)"
        Update-WPFObject $Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Window)"
    Update-WPFObject $WPFObject $ScriptBlock

    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
