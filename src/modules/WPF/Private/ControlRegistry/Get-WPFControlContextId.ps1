function Get-WPFControlContextId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object] $InputObject
    )

    if (-not $InputObject) {
        return $null
    }

    $Property = $InputObject.PSObject.Properties['_WPFContextId']
    if ($Property) {
        return [string] $Property.Value
    }

    return $null
}
