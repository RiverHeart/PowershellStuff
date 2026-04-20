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
    [OutputType([RowDefinition])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Name = '__NamelessRow__',
        [GridLength] $Height = [GridLength]::Auto
    )

    try {
        $WPFObject = [RowDefinition] @{
            Name = $Name
            Height = $Height
        }
        Add-WPFType $WPFObject 'GridDefinition'
    } catch {
        Write-Error "Failed to create '(RowDefinition) with error: $_"
    }

    return $WPFObject
}
