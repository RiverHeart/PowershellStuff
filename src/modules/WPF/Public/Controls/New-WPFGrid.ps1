<#
.SYNOPSIS
    Creates a WPF Grid object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.grid
#>
function New-WPFGrid {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Grid])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        [int] $Rows = 0,
        [int] $Columns = 0
    )

    try {
        $WPFObject = [System.Windows.Controls.Grid] @{
            Name = $Name
        }
        for ($i = 0; $i -lt $Rows; $i++) {
            $WPFObject.RowDefinitions.Add(
                [System.Windows.Controls.RowDefinition] @{ Height = [System.Windows.GridLength]::Auto }
            )
        }
        for ($i = 0; $i -lt $Columns; $i++) {
            $WPFObject.ColumnDefinitions.Add(
                [System.Windows.Controls.ColumnDefinition] @{ Width = [System.Windows.GridLength]::Auto }
            )
        }
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Grid) with error: $_"
    }

    return $WPFObject
}
