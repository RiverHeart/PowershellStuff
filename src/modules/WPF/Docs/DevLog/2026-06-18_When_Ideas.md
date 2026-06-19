Recent experiments in enhancing DSL binding ergonomics led to the creation of the [Link](../KeywordReference.md#link) keyword. The way it leveraged state got me thinking about ways that the `When` keyword could do the same.

The first obvious change is adding a `-State` flag so users can reference state directly without going through the control tag. Directly referencing app state would allow us to control when events fire using declarative flags like `-Is` instead `if` blocks. In the example below, the two versions are functionally identical but the second is far more concise while still being understandable.

```pwsh
State @{ IsFitMode = $True }

When SizeChanged {
    if ($this.Tag.IsFitMode) {
        Invoke-ImageViewerFitToWindow
    }
}
# vs
When -Event SizeChanged -State IsFitMode -Is $True { Invoke-ImageViewerFitToWindow }
```

`When` could also be used to define event handlers for observable state. A `-Becomes` flag could be used to execute only when the state is set to a value.

```pwsh
When -State IsFitMode -Becomes $true { Invoke-ImageViewerFitToWindow }
```

For more granual control, a `-Changes` flag could be used for when the value changes and modified by helpers `-To`/`-From` to specify the exact state transition. This is obviously less clean than a transition table but optimizations could be made behind the scenes if it becomes an issue.

```pwsh
When -State RotationAngle -Changes { Invoke-ImageViewerApplyRotation }
When -State IsFitMode -Changes -To $true { Invoke-ImageViewerFitToWindow }
When -State IsFitMode -Changes -To $true -From $false { Invoke-ImageViewerFitToWindow }
```

The issue as always is with scoping. I could test whether this is possible instead of just speculating but I'm lazy, the syntax is nice regardless of its current viability, and I can always revisit this later.
