<#
.SYNOPSIS
    Creates a WPF Image object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.image
#>
function New-WPFImage {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Image])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
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

    return $WPFObject
}
