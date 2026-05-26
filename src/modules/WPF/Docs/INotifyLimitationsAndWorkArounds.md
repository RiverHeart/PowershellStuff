# INotify Limitations and Workarounds

## Context
This note captures what we learned while debugging WPF state updates in the WPF DSL.

## 1) Why ETS-only state was insufficient
- The original public state surface was a wrapper object with ETS-added members (PowerShell ScriptProperties).
- The internal object raised PropertyChanged, but WPF bindings were often pointed at the wrapper/DataContext surface.
- Result: behavior could appear correct in some places (especially with manual binding refreshes), but automatic WPF updates were not reliably wired through the same notifying source object.

Key takeaway:
- Having INotifyPropertyChanged somewhere in the stack is not enough.
- The object used as the binding source must be the one that participates correctly in change notification for the bound properties.

## 2) Generated CLR type approach (works)
- We implemented runtime C# generation for a type that:
  - Implements INotifyPropertyChanged.
  - Exposes real CLR properties for each state key.
  - Raises PropertyChanged from each property setter.
- This gives reliable WPF binding behavior without manual UpdateTarget calls.

Limitation of this approach:
- Property shape is fixed at creation time.
- Any new ETS/non-CLR members added later are outside the generated CLR property model and are not part of that strongly-typed, generated binding surface.

## 3) What we validated about dynamic binding

We tested two dynamic approaches directly with WPF bindings.

### ExpandoObject
- ExpandoObject implements INotifyPropertyChanged.
- WPF uses IDynamicMetaObjectProvider to support ExpandoObject, so we're not limited to CLR reflection paths.
- WPF binding can be Active and update automatically when ExpandoObject members change.
- Missing properties are handled gracefully by the binding engine.

Important caveat in PowerShell:
- ExpandoObject also exposes an adapter/interface surface that can collide with user property names such as Count.
- Those collisions are a PowerShell ergonomics problem even when WPF binding itself works.

### DynamicObject + INotifyPropertyChanged
- A custom DynamicObject that stores values in an internal dictionary also works with WPF binding.
- It avoids the ExpandoObject adapter/member collision problem while keeping the same dynamic binding benefits.
- PowerShell member access and WPF binding updates both work for properties like Count.

Conclusion:
- Dynamic binding is fully viable in WPF for this module.
- DynamicObject ended up being the better default because it keeps the dynamic behavior without ExpandoObject's adapter quirks.

## 4) Options going forward
- Keep generated CLR type:
  - Pros: explicit bindable shape, strong predictability.
  - Cons: upfront property definition and codegen complexity.
- Use ExpandoObject-based state:
  - Pros: simple implementation, dynamic property model, automatic notifications.
  - Cons: PowerShell adapter/member collisions can make common names awkward or unsafe.
- Use DynamicObject-based state:
  - Pros: dynamic property model, automatic notifications, avoids ExpandoObject member-surface collisions.
  - Cons: still requires a small compiled helper type.

Current decision:
- New-WPFObservableState now defaults to the DynamicObject implementation.
- GeneratedClr remains available as an explicit fallback.
- ExpandoObject remains available as an explicit implementation for comparison and experimentation.

## 5) Practical guidance
- For WPF auto-updating bindings, ensure the binding source object itself is the notifying state surface.
- Avoid relying on manual binding refreshes except as deliberate fallback behavior.
- Keep tests that assert real automatic updates so regressions are visible.
- Prefer DynamicObject as the default dynamic state surface in this module.
- Use GeneratedClr when you want a fixed property shape.
- Use ExpandoObject only when its PowerShell member-surface quirks are acceptable for the scenario.


## Reading Materials
* https://learn.microsoft.com/en-us/dotnet/desktop/wpf/data/binding-sources-overview
* https://stackoverflow.com/a/76387580/5339918
