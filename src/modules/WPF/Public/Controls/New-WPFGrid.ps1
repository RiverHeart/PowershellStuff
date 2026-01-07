<#
.SYNOPSIS
    Creates a WPF Grid object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.grid
#>
function New-WPFGrid {
    [CmdletBinding(DefaultParameterSetName='Implicit')]
    [Alias('Grid')]
    [OutputType([System.Windows.Controls.Grid])]
    param(
        [Parameter(Mandatory,ParameterSetName='Explicit',Position=0)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [int] $Rows,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=2)]
        [int] $Columns,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=3)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=1)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.Grid] @{
            Name = $Name
        }
        for ($i = 0; $i -lt $Rows; $i++) {
            $InputObject.RowDefinitions.Add(
                [System.Windows.Controls.RowDefinition] @{ Height = [System.Windows.GridLength]::Auto }
            )
        }
        for ($i = 0; $i -lt $Columns; $i++) {
            $InputObject.ColumnDefinitions.Add(
                [System.Windows.Controls.RowDefinition] @{ Width = [System.Windows.GridLength]::Auto }
            )
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
        Update-WPFObject $WPFObject $ScriptBlock
    } catch {
        Write-Error "Failed to create '$Name' (Grid) with error: $_"
    }
    return $WPFObject
}
