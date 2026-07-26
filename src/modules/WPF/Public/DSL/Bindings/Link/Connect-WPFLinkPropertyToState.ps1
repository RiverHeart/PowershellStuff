function Connect-WPFLinkPropertyToState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourceProperty,

        [Parameter(Mandatory)]
        [string] $TargetState,

        [Parameter(Mandatory)]
        [object] $State,

        [Parameter(Mandatory)]
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

    $ValueConverter = New-WPFLinkValueConverter `
        -HasMap $HasMap `
        -HasTransform $HasTransform `
        -HasDefault $HasDefault `
        -UseStrictMap $UseStrictMap `
        -UseInvert $UseInvert `
        -Map $Map `
        -Default $Default `
        -Transform $Transform

    $BindingConfiguration = {
        $this.Mode = [System.Windows.Data.BindingMode]::OneWayToSource
        $this.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
        $this.Converter = New-WPFValueConverter $ValueConverter $ValueConverter
    }.GetNewClosure()

    BindProperty `
        -Property $SourceProperty `
        -Path $TargetState `
        -Source $State `
        -InputObject $InputObject `
        -ScriptBlock $BindingConfiguration
}
