<#
.SYNOPSIS
    Creates a WPF TextBox object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textbox
#>
function New-WPFTextBox {
    [OutputType([System.Windows.Controls.TextBox])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    try {
        $WPFObject = [System.Windows.Controls.TextBox] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    return $WPFObject
}
