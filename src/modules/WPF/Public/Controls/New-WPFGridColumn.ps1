using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a WPF ColumnDefinition object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.columndefinition
#>
function New-WPFGridColumn {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.ColumnDefinition])]
    param(
        [string] $Name = '__NamelessColumn__',
        [System.Windows.GridLength] $Width = [System.Windows.GridLength]::Auto
    )

    try {
        $WPFObject = [System.Windows.Controls.ColumnDefinition] @{
            Name = $Name
            Width = $Width
        }
        Add-WPFType $WPFObject 'GridDefinition'
    } catch {
        Write-Error "Failed to create (ColumnDefinition) with error: $_"
    }

    return $WPFObject
}
