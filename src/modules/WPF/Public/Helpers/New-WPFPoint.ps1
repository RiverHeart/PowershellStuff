<#
.SYNOPSIS
    Shorthand for returning a Point type.

.EXAMPLE
    Assign 200x300 Size type to size variable.

    $Size = Point 200 300
#>
function New-WPFPoint {
    [CmdletBinding()]
    [OutputType([System.Drawing.Point])]
    [Alias('Point')]
    param(
        [Parameter(Mandatory)]
        [int] $Width,

        [Parameter(Mandatory)]
        [int] $Height
    )

    return [System.Drawing.Point]::new($Width, $Height)
}
