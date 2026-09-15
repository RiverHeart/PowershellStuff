function Test-WPFLinkMember {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MemberName
    )

    if ($null -eq $InputObject) {
        return $false
    }

    if ($InputObject.PSObject.Methods['ContainsProperty']) {
        try {
            return [bool] ($InputObject.ContainsProperty($MemberName))
        } catch {
        }
    }

    if ($null -ne $InputObject.PSObject.Properties[$MemberName]) {
        return $true
    }

    return ($null -ne $InputObject.GetType().GetProperty($MemberName))
}
