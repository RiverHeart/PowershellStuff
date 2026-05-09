function BoundTo {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $Target
    )

    [pscustomobject]@{
        PSTypeName = 'WPF.BoundToSpec'
        Target     = $Target
    }
}
