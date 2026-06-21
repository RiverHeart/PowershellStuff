<#
.SYNOPSIS
    Keyword for reactive state handlers.

.DESCRIPTION
    Registers a handler that fires when observable state on the parent control's Tag
    object reaches a specific value or transitions through a change.

    Use -Becomes to fire once when a state property reaches a target value.
    Use -Changes to fire on any change, optionally filtered by -To and/or -From.

    The handler scriptblock runs with:
    - $this: the parent control where When was declared
    - $StateValue: the new state value
    - $PreviousStateValue: the prior state value (Changes mode)
    - $_ / $PSItem: alias for $StateValue

    For WPF event handlers, use the On keyword instead.

.EXAMPLE
    Window 'Main' {
        State @{ IsFitMode = $false }

        When IsFitMode -Becomes $true {
            Invoke-FitToWindow
        }
    }

.EXAMPLE
    Window 'Main' {
        State @{ RotationAngle = 0 }

        When RotationAngle -Changes {
            Write-Debug "Rotation is now $StateValue"
        }
    }

.EXAMPLE
    Window 'Main' {
        State @{ IsFitMode = $false }

        When IsFitMode -Changes -To $true {
            Invoke-FitToWindow
        }
    }
#>
function When {
    [CmdletBinding(DefaultParameterSetName = 'StateBecomes')]
    [Alias('-When')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'StateBecomes')]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'StateChanges')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFState @args })]
        [string] $State,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'StateBecomes')]
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'StateChanges')]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory, ParameterSetName = 'StateBecomes')]
        [AllowNull()]
        [object] $Becomes,

        [Parameter(Mandatory, ParameterSetName = 'StateChanges')]
        [switch] $Changes,

        [Parameter(ParameterSetName = 'StateChanges')]
        [AllowNull()]
        [object] $To,

        [Parameter(ParameterSetName = 'StateChanges')]
        [AllowNull()]
        [object] $From,

        [object] $InputObject
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name "When $State"
        return
    }

    # Auto-attach self to parent if one exists
    if (-not $InputObject) {
        $InputObject = $PSCmdlet.GetVariableValue('this')
        if (-not $InputObject) {
            Write-Warning "When: Parent not found for state handler on '$State'."
            return
        }
    }

    $StateObject = $InputObject.Tag
    if ($null -eq $StateObject) {
        Write-Error "When: '$State' requires an observable state object on '$($InputObject.Name).Tag'."
        return
    }

    $AddBindingMethod = $StateObject.PSObject.Methods['AddBinding']
    if ($null -eq $AddBindingMethod) {
        Write-Error "When: '$($InputObject.Name).Tag' does not support AddBinding(). Use State @{ ... } to create observable state first."
        return
    }

    $GetValueMethod = $StateObject.PSObject.Methods['GetValue']
    $StateProperty = $StateObject.PSObject.Properties[$State]
    if ($null -eq $GetValueMethod -and $null -eq $StateProperty) {
        Write-Error "When: State property '$State' does not exist on '$($InputObject.Name).Tag'."
        return
    }

    $PreviousStateValue = if ($null -ne $GetValueMethod) {
        $StateObject.GetValue($State)
    } else {
        $StateProperty.Value
    }

    $PSVars = New-WPFVariableList -InputObject $InputObject -CallerSessionState $PSCmdlet.SessionState
    if ($PSCmdlet.ParameterSetName -eq 'StateBecomes') {
        Write-Debug "Adding state-reactive handler for '$State' on '$($InputObject.Name)' (fires when value becomes '$Becomes')."
    } else {
        Write-Debug "Adding state-reactive change handler for '$State' on '$($InputObject.Name)' (To specified: $($PSBoundParameters.ContainsKey('To')); From specified: $($PSBoundParameters.ContainsKey('From')))."
    }

    $StateCallback = {
        param($CurrentStateValue)

        $ShouldInvoke = $false

        if ($PSCmdlet.ParameterSetName -eq 'StateBecomes') {
            $HasBecomeValue = [object]::Equals($CurrentStateValue, $Becomes)
            $WasBecomeValue = [object]::Equals($PreviousStateValue, $Becomes)
            $ShouldInvoke = $HasBecomeValue -and -not $WasBecomeValue
        } else {
            $IsChanged = -not [object]::Equals($CurrentStateValue, $PreviousStateValue)
            $MatchesTo = if ($PSBoundParameters.ContainsKey('To')) {
                [object]::Equals($CurrentStateValue, $To)
            } else {
                $true
            }
            $MatchesFrom = if ($PSBoundParameters.ContainsKey('From')) {
                [object]::Equals($PreviousStateValue, $From)
            } else {
                $true
            }

            $ShouldInvoke = $IsChanged -and $MatchesTo -and $MatchesFrom
        }

        if ($ShouldInvoke) {
            $AdditionalVars = [System.Collections.Generic.List[psvariable]]::new()
            $AdditionalVars.Add([psvariable]::new('_', $CurrentStateValue))
            $AdditionalVars.Add([psvariable]::new('PSItem', $CurrentStateValue))
            $AdditionalVars.Add([psvariable]::new('StateValue', $CurrentStateValue))
            $AdditionalVars.Add([psvariable]::new('PreviousStateValue', $PreviousStateValue))

            $AllVars = [System.Collections.Generic.List[psvariable]]::new()
            foreach ($Var in $PSVars) {
                $AllVars.Add($Var)
            }
            foreach ($Var in $AdditionalVars) {
                $AllVars.Add($Var)
            }
            $null = $ScriptBlock.InvokeWithContext($null, $AllVars)
        }

        $PreviousStateValue = $CurrentStateValue
    }.GetNewClosure()

    $StateObject.AddBinding($State, $StateCallback, $false)
}
