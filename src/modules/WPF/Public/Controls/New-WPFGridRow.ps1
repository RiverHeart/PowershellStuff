using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a WPF RowDefinition object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.rowdefinition
#>
function New-WPFGridRow {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.RowDefinition])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Name = '__NamelessRow__',
        [System.Windows.GridLength] $Height = [System.Windows.GridLength]::Auto
    )

    try {
        $WPFObject = [System.Windows.Controls.RowDefinition] @{
            Name = $Name
            Height = $Height
        }
        Add-WPFType $WPFObject 'GridDefinition'
    } catch {
        Write-Error "Failed to create '(RowDefinition) with error: $_"
    }

    return $WPFObject
}
