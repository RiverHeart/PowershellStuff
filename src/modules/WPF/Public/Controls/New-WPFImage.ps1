<#
.SYNOPSIS
    Creates a WPF Image object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.image
#>
function New-WPFImage {
    [CmdletBinding()]
    [Alias('Image')]
    [OutputType([System.Windows.Controls.Image])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [scriptblock] $ScriptBlock,

        [switch] $NoAutoAttach
    )

    try {
        $WPFObject = [System.Windows.Controls.Image] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Image) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Write-Debug "Beginning auto-attach for $Name (Image)"
        Update-WPFObject $Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Image)"
    Update-WPFObject $WPFObject $ScriptBlock

    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
