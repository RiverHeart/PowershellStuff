<#
.SYNOPSIS
    Limits a value between an optional minimum and maximum.

.DESCRIPTION
    Limits a value between an optional minimum and maximum.

.NOTES
    This function uses an official verb in the canonical name to avoid import warnings.
    Users are encouraged to use the aliases for general use.

.EXAMPLE
    Limit-WPFNumber -Value 15 -Minimum 20

.EXAMPLE
    Limit-WPFNumber -Value 500 -Minimum 20 -Maximum 300
#>
function Limit-WPFNumber {
    [CmdletBinding()]
    [Alias('Clamp', 'Clamp-Number')]
    [OutputType([double])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [double] $Value,

        [double] $Minimum = [double]::NegativeInfinity,

        [double] $Maximum = [double]::PositiveInfinity
    )

    process {
        [System.Math]::Min($Maximum, [System.Math]::Max($Minimum, $Value))
    }
}
