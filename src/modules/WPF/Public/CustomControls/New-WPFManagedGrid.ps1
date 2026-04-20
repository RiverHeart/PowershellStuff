<#
.SYNOPSIS
    Creates GridManager object
#>
function New-WPFManagedGrid {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Windows.Controls.Grid] $Grid
    )

    return [ManagedGrid]::new($Grid)
}
