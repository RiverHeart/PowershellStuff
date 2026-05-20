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

.PARAMETER Implementation
    Selects the state engine.
    - DynamicObject (default): custom DynamicObject + INotifyPropertyChanged without Expando adapter surface.
    - ExpandoObject: dynamic members, INotifyPropertyChanged, no runtime code generation.
    - GeneratedClr: runtime-generated CLR type with fixed property shape.

    When using ExpandoObject mode, names that collide with adapted members
    (for example, Count) automatically fall back to GeneratedClr unless you
    explicitly request ExpandoObject.

.EXAMPLE
    $state = New-WPFObservableState @{ IsFullScreen = $false; Count = 0 }
    $state.IsFullScreen = $true  # automatically updates any WPF bindings and callbacks
#>
function New-WPFObservableState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable] $Properties,

        [Parameter()]
        [ValidateSet('GeneratedClr', 'ExpandoObject', 'DynamicObject')]
        [string] $Implementation = 'DynamicObject'
    )

    $propertyNames = [List[string]]::new()
    foreach ($key in $Properties.Keys) {
        $name = [string] $key
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw 'State property names must be non-empty strings.'
        }

        # Use CLR-friendly names so WPF can bind through reflection to real properties.
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "State property '$name' is not a valid CLR property name. Use letters, digits, and underscore, and start with a letter or underscore."
        }

        [void] $propertyNames.Add($name)
    }

    $effectiveImplementation = $Implementation
    if ($effectiveImplementation -eq 'ExpandoObject') {
        $reservedMemberNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $emptyExpando = [System.Dynamic.ExpandoObject]::new()
        foreach ($existingMember in $emptyExpando.PSObject.Properties.Name) {
            [void] $reservedMemberNames.Add([string] $existingMember)
        }

        $conflictingNames = [List[string]]::new()
        foreach ($name in $propertyNames) {
            if ($reservedMemberNames.Contains($name)) {
                [void] $conflictingNames.Add($name)
            }
        }

        if ($conflictingNames.Count -gt 0) {
            if ($PSBoundParameters.ContainsKey('Implementation')) {
                throw "State properties [$($conflictingNames -join ', ')] conflict with existing ExpandoObject/adapter member names in PowerShell. Choose different property names or use -Implementation GeneratedClr."
            }

            $effectiveImplementation = 'GeneratedClr'
            Write-Verbose "New-WPFObservableState: falling back to GeneratedClr because ExpandoObject member-name conflicts were detected: $($conflictingNames -join ', ')."
        }
    }

    if ($effectiveImplementation -eq 'GeneratedClr') {
        $sortedNames = @($propertyNames | Sort-Object)
        $typeSignature = ($sortedNames -join '|')
        $typeSignatureBytes = [System.Text.Encoding]::UTF8.GetBytes($typeSignature)
        $sha = [System.Security.Cryptography.SHA1]::Create()
        try {
            $hashBytes = $sha.ComputeHash($typeSignatureBytes)
        } finally {
            $sha.Dispose()
        }
        $hashString = [BitConverter]::ToString($hashBytes).Replace('-', '')
        $typeName = "WPFObservableState_$hashString"

        if (-not ([PSTypeName] $typeName).Type) {
            $fieldBuilder = [System.Text.StringBuilder]::new()
            $propertyBuilder = [System.Text.StringBuilder]::new()
            $getSwitchBuilder = [System.Text.StringBuilder]::new()
            $setSwitchBuilder = [System.Text.StringBuilder]::new()

            foreach ($name in $sortedNames) {
                $fieldName = "_$name"
                [void] $fieldBuilder.AppendLine("    private object $fieldName;")

                [void] $propertyBuilder.AppendLine("    public object $name")
                [void] $propertyBuilder.AppendLine('    {')
                [void] $propertyBuilder.AppendLine("        get => $fieldName;")
                [void] $propertyBuilder.AppendLine('        set')
                [void] $propertyBuilder.AppendLine('        {')
                [void] $propertyBuilder.AppendLine("            if (object.Equals($fieldName, value))")
                [void] $propertyBuilder.AppendLine('                return;')
                [void] $propertyBuilder.AppendLine('')
                [void] $propertyBuilder.AppendLine("            $fieldName = value;")
                [void] $propertyBuilder.AppendLine("            OnPropertyChanged(nameof($name));")
                [void] $propertyBuilder.AppendLine('        }')
                [void] $propertyBuilder.AppendLine('    }')
                [void] $propertyBuilder.AppendLine('')

                [void] $getSwitchBuilder.AppendLine("            case nameof($name):")
                [void] $getSwitchBuilder.AppendLine("                return $name;")

                [void] $setSwitchBuilder.AppendLine("            case nameof($name):")
                [void] $setSwitchBuilder.AppendLine("                $name = value;")
                [void] $setSwitchBuilder.AppendLine('                return;')
            }

            $classCode = @"
using System;
using System.ComponentModel;

public class $typeName : INotifyPropertyChanged
{
$($fieldBuilder.ToString())
    public event PropertyChangedEventHandler PropertyChanged;

$($propertyBuilder.ToString())
    public object GetValue(string propertyName)
    {
        switch (propertyName)
        {
$($getSwitchBuilder.ToString())
            default:
                throw new ArgumentException($"Unknown state property '{propertyName}'.", nameof(propertyName));
        }
    }

    public void SetValue(string propertyName, object value)
    {
        switch (propertyName)
        {
$($setSwitchBuilder.ToString())
            default:
                throw new ArgumentException($"Unknown state property '{propertyName}'.", nameof(propertyName));
        }
    }

    protected void OnPropertyChanged(string propertyName)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
"@

            Add-Type -TypeDefinition $classCode
        }

        # Create the observable instance with CLR properties and initialize values.
        $state = New-Object $typeName
        foreach ($name in $propertyNames) {
            $state.SetValue($name, $Properties[$name])
        }
    } elseif ($effectiveImplementation -eq 'ExpandoObject') {
        # ExpandoObject exposes dynamic members and implements INotifyPropertyChanged.
        $state = [System.Dynamic.ExpandoObject]::new()
        foreach ($name in $propertyNames) {
            $null = ($state.$name = $Properties[$name])
        }
    } else {
        $typeName = 'WPFDynamicObservableState'
        if (-not ([PSTypeName] $typeName).Type) {
            $classCode = @"
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Dynamic;

public class WPFDynamicObservableState : DynamicObject, INotifyPropertyChanged
{
    private readonly Dictionary<string, object> _storage = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
    public event PropertyChangedEventHandler PropertyChanged;

    public override bool TryGetMember(GetMemberBinder binder, out object result)
    {
        if (_storage.TryGetValue(binder.Name, out result))
            return true;

        result = null;
        return true;
    }

    public override bool TrySetMember(SetMemberBinder binder, object value)
    {
        SetValue(binder.Name, value);
        return true;
    }

    public object GetValue(string propertyName)
    {
        object result;
        _storage.TryGetValue(propertyName, out result);
        return result;
    }

    public bool ContainsProperty(string propertyName)
    {
        return _storage.ContainsKey(propertyName);
    }

    public void SetValue(string propertyName, object value)
    {
        object existing;
        if (_storage.TryGetValue(propertyName, out existing) && object.Equals(existing, value))
            return;

        _storage[propertyName] = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
"@
            Add-Type -TypeDefinition $classCode
        }

        $state = New-Object $typeName
        foreach ($name in $propertyNames) {
            $state.SetValue($name, $Properties[$name])
        }
    }

    # Keep track of PowerShell callbacks separately.
    $bindingsDict = [Dictionary[string, List[scriptblock]]]::new()

    # Keep the callback dictionary on the public state object for AddBinding.
    Add-Member -InputObject $state -MemberType NoteProperty -Name _Bindings -Value $bindingsDict -Force

    # Bridge PropertyChanged -> AddBinding callbacks so callback behavior remains intact.
    $bindingsRef = $bindingsDict
    $propertyChangedHandler = {
        param($sender, $eventArgs)

        $callbacks = $null
        $propertyName = [string] $eventArgs.PropertyName
        if ($bindingsRef.TryGetValue($propertyName, [ref] $callbacks)) {
            $currentValue = $null
            $getValueMethod = $sender.PSObject.Methods['GetValue']
            if ($null -ne $getValueMethod) {
                $currentValue = $sender.GetValue($propertyName)
            } else {
                $senderProperty = $sender.PSObject.Properties[$propertyName]
                if ($null -ne $senderProperty) {
                    $currentValue = $senderProperty.Value
                }
            }

            foreach ($callback in $callbacks) {
                & $callback $currentValue
            }
        }
    }.GetNewClosure()

    $state.add_PropertyChanged($propertyChangedHandler)

    # Add AddBinding method for PowerShell callbacks
    Add-Member -InputObject $state -MemberType ScriptMethod -Name AddBinding -Value {
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
            $value = $null
            $getValueMethod = $this.PSObject.Methods['GetValue']
            if ($null -ne $getValueMethod) {
                $containsPropertyMethod = $this.PSObject.Methods['ContainsProperty']
                if ($null -ne $containsPropertyMethod -and -not $this.ContainsProperty($PropertyName)) {
                    throw "State property '$PropertyName' does not exist."
                }

                $value = $this.GetValue($PropertyName)
            } else {
                $property = $this.PSObject.Properties[$PropertyName]
                if ($null -eq $property) {
                    throw "State property '$PropertyName' does not exist."
                }

                $value = $property.Value
            }

            & $Callback $value
        }
    } -Force

    # ExpandoObject implements IEnumerable, so return it as a single pipeline object.
    return ,$state
}
