<#
.SYNOPSIS
    Creates a WPF Image object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.image
#>
function Image {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.Image])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [scriptblock] $ScriptBlock
    )

    try {
        $Image = [System.Windows.Controls.Image] @{
            Name = $Name
        }
        Register-WPFObject $Name $Image
        Add-WPFType $Image 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Image) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (Image)"
        Update-WPFObject $Parent $Image
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Image)"
    Update-WPFObject $Image $ScriptBlock

    if ($this.Parent) { return }
    return $Image
}
