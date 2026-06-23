<#
.SYNOPSIS
    Retrieves the WPF control context ID associated with a given input object.

.DESCRIPTION
    This helper retrieves the context ID associated with an input object. The
    input object must already be associated with a context, or this helper will
    return null. This helper does not perform any resolution or fallback logic;
    it simply retrieves the context ID directly from the input object.
#>
function Get-WPFControlContextId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object] $InputObject
    )

    $Property = $InputObject.PSObject.Properties['_WPFContextId']
    if ($Property) {
        return [string] $Property.Value
    }

    return $null
}
