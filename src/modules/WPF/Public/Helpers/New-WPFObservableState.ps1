using namespace System
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a reactive state object for use with WPF bindings and PowerShell callbacks.

.DESCRIPTION
    Returns an object with observable properties that implement INotifyPropertyChanged.
    This makes the object fully compatible with WPF data binding while also supporting
    PowerShell callbacks via AddBinding().

    When a property value changes, all WPF bindings update automatically, and any
    callbacks registered via AddBinding() are invoked.

    Use with the Watch DSL keyword to declaratively wire control properties to state,
    or bind directly in DataTemplates and XAML-like DSL code.

.PARAMETER Properties
    A hashtable of initial property names and values.

.EXAMPLE
    $state = New-WPFObservableState @{ IsFullScreen = $false; Count = 0 }
    $state.IsFullScreen = $true  # automatically updates any WPF bindings and callbacks
#>
function New-WPFObservableState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable] $Properties
    )

    # Create a class that implements INotifyPropertyChanged for WPF binding
    $classCode = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;

public class WPFObservableState : INotifyPropertyChanged
{
    private Dictionary<string, object> _values;

    public event PropertyChangedEventHandler PropertyChanged;

    public WPFObservableState(Dictionary<string, object> initialValues)
    {
        _values = new Dictionary<string, object>(initialValues);
    }

    public object GetValue(string propertyName)
    {
        object result;
        _values.TryGetValue(propertyName, out result);
        return result;
    }

    public void SetValue(string propertyName, object value)
    {
        if (_values.ContainsKey(propertyName) && _values[propertyName] == value)
            return;

        _values[propertyName] = value;
        OnPropertyChanged(propertyName);
    }

    protected void OnPropertyChanged(string propertyName)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
'@

    # Load the class if not already loaded
    $typeName = 'WPFObservableState'
    if (-not ([PSTypeName] $typeName).Type) {
        Add-Type -TypeDefinition $classCode
    }

    # Convert hashtable to Dictionary<string, object>
    $dict = [Dictionary[string, object]]::new()
    foreach ($key in $Properties.Keys) {
        $dict[$key] = $Properties[$key]
    }

    # Create the C# observable instance
    $observable = [WPFObservableState]::new($dict)

    # Keep track of PowerShell callbacks separately - must be in parent scope for closure
    $bindingsDict = [Dictionary[string, List[scriptblock]]]::new()

    # Create wrapper object with properties and methods
    $wrapper = [pscustomobject] @{
        _Observable = $observable
        _Bindings = $bindingsDict
    }

    # Add ScriptProperties that delegate to GetValue/SetValue
    foreach ($key in $Properties.Keys) {
        $propertyName = $key
        $getter = { $this._Observable.GetValue($propertyName) }.GetNewClosure()
        $setter = {
            param($value)
            $this._Observable.SetValue($propertyName, $value)
            # Invoke any PowerShell callbacks
            $cbs = $null
            if ($this._Bindings.TryGetValue($propertyName, [ref] $cbs)) {
                foreach ($cb in $cbs) { & $cb $value }
            }
        }.GetNewClosure()

        $wrapper | Add-Member -MemberType ScriptProperty -Name $key -Value $getter -SecondValue $setter -Force
    }

    # Add AddBinding method for PowerShell callbacks
    $wrapper | Add-Member -MemberType ScriptMethod -Name AddBinding -Value {
        param(
            [string]      $PropertyName,
            [scriptblock] $Callback,
            [bool]        $FireImmediately = $true
        )

        if (-not $this._Bindings.ContainsKey($PropertyName)) {
            $this._Bindings[$PropertyName] = [List[scriptblock]]::new()
        }
        $this._Bindings[$PropertyName].Add($Callback)

        if ($FireImmediately) {
            & $Callback $this._Observable.GetValue($PropertyName)
        }
    } -Force

    return $wrapper
}
