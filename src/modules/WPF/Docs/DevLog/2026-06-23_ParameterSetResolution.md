Learned a neat trick from Gemini today. It turns out that `[ValidateScript()]` runs during the evaluation phase when PowerShell is picking a parameter set to see if input can be bound to parameters in the set. During this phase failure to bind doesn't throw an error immediately.

One thing that has plagued me during the development of the DSL keywords is the fact that `[Scriptblock]` casts to `[string]`. Scriptblocks would always qualify for position 0's `[string]` which led me to make name mandatory instead of optional. It was always possible to just accept an `[object]` and inspect the type but that prevents legitimate objects from casting to `[string] and checking types in the function body gets messy very fast.

With this new trick, it becomes possible to disqualify scriptblocks from string parameters like so,

```powershell
param(
    [Parameter(ParameterSetName = 'Name', Position = 0)]
    [ValidateScript({ -not ($_ -is [scriptblock]) })]
    [string] $Name = '__Nameless__',

    [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
    [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
    [scriptblock] $ScriptBlock
)
```

With this pattern, I can make control names optional again and with a default of '__Nameless__' I can just have `Register-WPFObject` silently return without registering the object. Guarding is still desirable to avoid the function call the first place of course but failure to guard won't lead to unnecessary registrations this way.
