function Resolve-WPFLinkEndpointKind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EndpointName,

        [AllowEmptyString()]
        [string] $RequestedKind,

        [Parameter(Mandatory)]
        [ValidateSet('Source', 'Target')]
        [string] $EndpointRole,

        [Parameter(Mandatory)]
        [bool] $PropertyExists,

        [Parameter(Mandatory)]
        [bool] $StateExists
    )

    $Kinds = @()
    if ($PropertyExists) {
        $Kinds += 'Property'
    }
    if ($StateExists) {
        $Kinds += 'State'
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedKind)) {
        if (-not ($Kinds -contains $RequestedKind)) {
            Write-Error "Link: $EndpointRole '$EndpointName' does not exist as $RequestedKind in the current context." -ErrorAction Continue
            return $null
        }
        return $RequestedKind
    }

    if ($Kinds.Count -eq 0) {
        Write-Error "Link: $EndpointRole '$EndpointName' was not found in current control properties or window state." -ErrorAction Continue
        return $null
    }

    if ($Kinds.Count -gt 1) {
        $KindParameter = if ($EndpointRole -eq 'Source') { '-FromKind' } else { '-ToKind' }
        Write-Error "Link: $EndpointRole '$EndpointName' is ambiguous (Property and State). Specify $KindParameter Property or State." -ErrorAction Continue
        return $null
    }

    return $Kinds[0]
}
