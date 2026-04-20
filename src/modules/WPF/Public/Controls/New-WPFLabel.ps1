<#
.SYNOPSIS
    Creates a WPF Label object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.label
#>
function New-WPFLabel {
    [OutputType([System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    try {
        $WPFObject = [System.Windows.Controls.Label] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Label) with error: $_"
    }

    return $WPFObject
}
