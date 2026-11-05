PowerShell classes don’t support C#-style custom property bodies:

```csharp
public string Name { get { ... } set { ... } }
```

Available options are:

* **Ordinary class properties:** `[string] $Name` — automatic storage, no custom accessor logic.
* **Interface implementation:** `get_Name()` / `set_Name()` satisfy the interface’s declared property.
* **Script properties:** `Add-Member -MemberType ScriptProperty` or `Update-TypeData`, allowing custom getters/setters without an interface.


**Interface Example**

```powershell
Add-Type @'
public interface ISetterExample { string Name { get; set; } }
'@

class SetterExample : ISetterExample {
    hidden [string] $StoredName
    [string] get_Name() { return $this.StoredName }
    [void] set_Name([string] $Value) { $this.StoredName = $Value }
}

$Example = [SetterExample]::new()
$Example.Name = 'Hello'
$Example.Name
```
