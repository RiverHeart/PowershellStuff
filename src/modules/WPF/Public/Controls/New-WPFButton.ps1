<#
.SYNOPSIS
    Creates a WPF Button object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.button
#>
function New-WPFButton {
    [OutputType([System.Windows.Controls.Button])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    try {
        $WPFObject = [System.Windows.Controls.Button] @{
            Name = $Name
            Content = $Content
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Button) with error: $_"
    }

    return $WPFObject
}
