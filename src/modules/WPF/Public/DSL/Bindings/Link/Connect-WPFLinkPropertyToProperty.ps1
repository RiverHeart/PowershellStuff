function Connect-WPFLinkPropertyToProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourceProperty,

        [Parameter(Mandatory)]
        [string] $TargetProperty,

        [Parameter(Mandatory)]
        [object] $InputObject
    )

    BindProperty `
        -Property $TargetProperty `
        -Path $SourceProperty `
        -Self `
        -InputObject $InputObject
}
