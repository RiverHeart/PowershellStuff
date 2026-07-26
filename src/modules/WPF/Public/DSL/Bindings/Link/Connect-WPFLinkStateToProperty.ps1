function Connect-WPFLinkStateToProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TargetProperty,

        [Parameter(Mandatory)]
        [string] $SourceState,

        [Parameter(Mandatory)]
        [string] $WindowName,

        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [bool] $HasMap,

        [Parameter(Mandatory)]
        [bool] $HasTransform,

        [Parameter(Mandatory)]
        [bool] $HasDefault,

        [Parameter(Mandatory)]
        [bool] $UseStrictMap,

        [Parameter(Mandatory)]
        [bool] $UseInvert,

        [AllowNull()]
        [hashtable] $Map,

        [AllowNull()]
        [object] $Default,

        [AllowNull()]
        [scriptblock] $Transform
    )

    $BindParams = @{
        Property = $TargetProperty
        To       = "$WindowName.Tag.$SourceState"
    }

    if ($HasMap -or $HasTransform -or $UseInvert) {
        $BindParams.Converter = New-WPFLinkValueConverter `
            -HasMap $HasMap `
            -HasTransform $HasTransform `
            -HasDefault $HasDefault `
            -UseStrictMap $UseStrictMap `
            -UseInvert $UseInvert `
            -Map $Map `
            -Default $Default `
            -Transform $Transform
    }
    if ($null -ne $InputObject) {
        $BindParams.InputObject = $InputObject
    }

    Bind @BindParams
}
