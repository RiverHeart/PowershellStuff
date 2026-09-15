function Get-WPFLinkValueOptionError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $HasMap,

        [Parameter(Mandatory)]
        [bool] $HasTransform,

        [Parameter(Mandatory)]
        [bool] $HasDefault,

        [Parameter(Mandatory)]
        [bool] $UseStrictMap
    )

    if ($HasMap -and $HasTransform) {
        return 'Link: Specify either -Map or -Transform, not both.'
    }

    if (-not $HasMap -and ($HasDefault -or $UseStrictMap)) {
        return 'Link: -Default and -StrictMap require -Map.'
    }

    if ($HasDefault -and $UseStrictMap) {
        return 'Link: -Default and -StrictMap cannot be combined.'
    }

    return $null
}
