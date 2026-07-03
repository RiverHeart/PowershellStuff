# User Defined Keyword Example

This example shows how to create a user-defined DSL keyword without modifying the WPF module itself.

It demonstrates four extension points:

1. Create a normal WPF object in PowerShell.
2. Register a control name with `Register-WPFObject`.
3. Annotate the object with `Add-WPFType -Type Control` so the DSL treats it like a standard control.
4. Register editor completion metadata with `Register-WPFCompletionType` so `$this` inside the custom keyword resolves against the expected WPF type.

Run the example:

```powershell
pwsh ./UserDefinedKeyword.ps1
```

What to look for:

* The custom `Badge` keyword behaves like a regular DSL control when nested inside `StackPanel`.
* Clicking `Inspect Ready Badge` shows that the created object carries the custom WPF metadata type name.
* The implementation uses only public module helpers, which makes it a good starting point for user-defined keyword experiments.
