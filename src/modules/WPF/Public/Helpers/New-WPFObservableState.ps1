<#
.SYNOPSIS
    Creates a reactive state object for use with the Bind DSL keyword.

.DESCRIPTION
    Returns a PSCustomObject with observable properties. When a property value
    changes, all callbacks registered via AddBinding() are invoked automatically.

    Use with the Bind DSL keyword to declaratively wire control properties to
    state without manually referencing controls in event handlers.

.PARAMETER Properties
    A hashtable of initial property names and values.

.EXAMPLE
    $state = New-WPFObservableState @{ IsFullScreen = $false; IsFileLoaded = $false }
    $state.IsFullScreen = $true  # automatically updates any bound control properties
#>
function New-WPFObservableState {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable] $Properties
    )

    $values   = @{}
    $bindings = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[scriptblock]]]::new()

    $state = [pscustomobject] @{
        _values   = $values
        _bindings = $bindings
    }

    foreach ($key in $Properties.Keys) {
        $values[$key] = $Properties[$key]
        $name = $key  # capture per-iteration for closures

        $getter = { $this._values[$name] }.GetNewClosure()
        $setter = {
            param($value)
            $this._values[$name] = $value
            $cbs = $null
            if ($this._bindings.TryGetValue($name, [ref] $cbs)) {
                foreach ($cb in $cbs) { & $cb $value }
            }
        }.GetNewClosure()

        $state | Add-Member -MemberType ScriptProperty -Name $key -Value $getter -SecondValue $setter
    }

    $state | Add-Member -MemberType ScriptMethod -Name AddBinding -Value {
        param(
            [string]      $PropertyName,
            [scriptblock] $Callback,
            [bool]        $FireImmediately = $true
        )
        if (-not $this._bindings.ContainsKey($PropertyName)) {
            $this._bindings[$PropertyName] = [System.Collections.Generic.List[scriptblock]]::new()
        }
        $this._bindings[$PropertyName].Add($Callback)
        if ($FireImmediately) {
            & $Callback $this._values[$PropertyName]
        }
    }

    return $state
}
