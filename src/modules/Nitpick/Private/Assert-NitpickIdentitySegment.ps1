function Assert-NitpickIdentitySegment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value,

        [Parameter(Mandatory)]
        [ValidateSet('Name', 'Namespace')]
        [string] $SegmentType
    )

    if ([string]::IsNullOrWhiteSpace($Value) -or
        $Value.IndexOfAny([char[]]@('/', '\', '*', '?', '[', ']')) -ge 0
    ) {
        throw "Nitpick $SegmentType '$Value' must be a nonempty single segment without path separators or wildcard syntax."
    }
}
