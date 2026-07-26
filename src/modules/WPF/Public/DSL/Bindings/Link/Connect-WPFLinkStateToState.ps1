function Connect-WPFLinkStateToState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourceState,

        [Parameter(Mandatory)]
        [string] $TargetState,

        [Parameter(Mandatory)]
        [object] $State,

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

    if ($null -eq $State.PSObject.Methods['AddBinding']) {
        Write-Error 'Link: State object does not support AddBinding(). Use State @{ ... } to create observable state first.'
        return
    }

    if ($State.PSObject.Methods['ContainsProperty']) {
        if (-not $State.ContainsProperty($SourceState)) {
            Write-Error "Link: Source state property '$SourceState' does not exist."
            return
        }
        if (-not $State.ContainsProperty($TargetState)) {
            Write-Error "Link: Target state property '$TargetState' does not exist."
            return
        }
    }

    $ValueConverter = New-WPFLinkValueConverter `
        -HasMap $HasMap `
        -HasTransform $HasTransform `
        -HasDefault $HasDefault `
        -UseStrictMap $UseStrictMap `
        -UseInvert $UseInvert `
        -Map $Map `
        -Default $Default `
        -Transform $Transform

    $StateCallback = {
        param($SourceValue)

        $FinalValue = & $ValueConverter $SourceValue
        if ($State.PSObject.Methods['GetValue'] -and
            [object]::Equals($State.GetValue($TargetState), $FinalValue)) {
            return
        }

        if ($State.PSObject.Methods['SetValue']) {
            $State.SetValue($TargetState, $FinalValue)
            return
        }

        $StateProperty = $State.PSObject.Properties[$TargetState]
        if ($null -eq $StateProperty) {
            throw "Link: Target state property '$TargetState' does not exist."
        }
        $State.$TargetState = $FinalValue
    }.GetNewClosure()

    $State.AddBinding($SourceState, $StateCallback)
}
