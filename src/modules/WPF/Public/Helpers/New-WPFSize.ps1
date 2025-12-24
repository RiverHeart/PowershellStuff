<#
.SYNOPSIS
    Shorthand for returning a Size type.

.EXAMPLE
    Assign 200x300 Size type to size variable.

    $Size = Size 200 300
#>
function New-WPFSize {
    [CmdletBinding()]
    [OutputType([System.Drawing.Size])]
    [Alias('Size')]
    param(
        [Parameter(Mandatory)]
        [int] $Width,

        [Parameter(Mandatory)]
        [int] $Height
    )

    return [System.Drawing.Size]::new($Width, $Height)
}
