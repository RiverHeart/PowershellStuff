function Set-WPFControlContext {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    Write-Debug "Setting WPF control context '$ContextId' for '$($InputObject.Name)'"
    if ($InputObject.PSObject.Properties['_WPFContextId']) {
        $InputObject.PSObject.Properties['_WPFContextId'].Value = $ContextId
    } else {
        $InputObject | Add-Member -MemberType NoteProperty -Name '_WPFContextId' -Value $ContextId -Force
    }
}
