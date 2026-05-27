**Proposal: Chrome Adapter Layer for Style Ergonomics**

**Summary**
Add an explicit Chrome abstraction inside `Style` that captures visual intent (corner radius, chrome border, content insets) while adapters translate that intent to control-specific WPF template parts.

This reduces template authoring burden for users without making `Setter` behavior implicit or surprising.

**Problem**
Current styling requires users to author control templates for common visual goals such as rounded inputs or polished button chrome. That complexity is implementation-level, not design-level.

Trying to solve this by making `Setter` globally smart would introduce hidden behavior and fragile control-specific carve-outs.

**Goals**
1. Preserve existing `Style` and `Setter` semantics.
2. Provide an explicit, easier surface for template-backed visuals.
3. Keep control-specific complexity isolated behind adapters.
4. Provide deterministic conflict and precedence behavior.
5. Roll out safely with narrow initial control support.

**Non-Goals**
1. No universal automatic template generation for every control in v1.
2. No silent mutation of style output when users only author plain `Setter` entries.
3. No breaking changes to existing style files.

**Proposed Surface**
```powershell
Style 'PrimaryButton' Button {
    Setter Background '#0A84FF'
    Setter Foreground '#FFFFFF'
    Setter Padding '14,8,14,8'

    Chrome {
        Setter CornerRadius 6
        Setter BorderBrush '#086FD5'
        Setter BorderThickness 2
    }

    Trigger IsMouseOver $true {
        Setter Background '#0978E6' -Scope Chrome
    }
}
```

Notes:
1. `Chrome` is explicit opt-in, not automatic behavior.
2. `-Scope Chrome` is optional sugar that maps trigger setters to chrome target parts.
3. Existing `Template` remains the advanced escape hatch.

**Abstraction Boundary**
1. Control scope: existing style setters for the target control.
2. Chrome scope: visual shell properties for generated chrome parts.
3. Content scope: content host alignment/inset behavior.

`Setter` remains literal and control-scoped unless authored inside a dedicated block/scope.

**Adapter Model**
Each adapter translates neutral Chrome intent into control-specific template output.

Contract:
1. `CanHandle([Type] $TargetType)`
2. `Validate($ChromeSpec)`
3. `BuildTemplateParts($ChromeSpec)`
4. `BuildBaseSetters($ChromeSpec)`
5. `BuildTriggerSetters($ChromeSpec)`

Registry resolution:
1. Exact type adapter match.
2. Family adapter fallback.
3. Clear unsupported error if no adapter exists.

**Neutral Chrome Spec (Internal)**
```powershell
[pscustomobject]@{
    TargetType = [System.Windows.Controls.Button]
    Chrome = @{
        CornerRadius = 6
        Background = '#0A84FF'
        BorderBrush = '#086FD5'
        BorderThickness = 2
    }
    Content = @{
        Padding = '14,8,14,8'
        HorizontalContentAlignment = 'Center'
        VerticalContentAlignment = 'Center'
    }
    TriggerOverrides = @{
        IsMouseOver = @{ Background = '#0978E6' }
    }
}
```

The spec is control-agnostic. Control details are adapter-owned.

**Conflict and Precedence Rules**
1. Do not implicitly merge control and chrome scopes.
2. For shell visuals, Chrome values win over control setters.
3. If Chrome omits a shell property, adapter may inherit from control setter.
4. Trigger setters override base values while trigger is active.
5. Optional debug warning when both scopes set same semantic property.

Example likely conflict: `Background`, `BorderBrush`, `BorderThickness`, `Padding`.

**Design Rationale: Scope vs Nested Chrome Triggers**
Use `-Scope Chrome` as the canonical trigger targeting mechanism.

Why this pattern:
1. It preserves one trigger grammar across the DSL (`Trigger`, `DataTrigger`, `MultiTrigger`).
2. It avoids introducing a parallel nested trigger language under `Chrome`.
3. It keeps parser, validation, and test surface area smaller and easier to maintain.

If nested chrome-only triggers are required, the DSL must duplicate trigger behavior across two surfaces:

```powershell
Style 'GhostButton' Button {
    Trigger IsEnabled $false {
        Setter Foreground '#A1AAB7'
    }

    Chrome {
        Trigger IsEnabled $false {
            Setter Background '#F8FAFC'
            Setter BorderBrush '#D2D9E3'
        }
    }
}
```

This splits one state condition into multiple blocks and increases authoring drift risk.

With `-Scope Chrome`, a single trigger model can still express both control-level and chrome-level changes without adding a second DSL grammar:

```powershell
Style 'GhostButton' Button {
    Trigger IsEnabled $false -Scope Chrome {
        Setter Background '#F8FAFC'
        Setter BorderBrush '#D2D9E3'
    }

    Trigger IsEnabled $false {
        Setter Foreground '#A1AAB7'
    }
}
```

Future sugar is still possible (for example `ChromeTrigger`) but should compile to the same `-Scope Chrome` behavior to avoid runtime divergence.

**Initial Adapters (MVP)**
1. ContentControl adapter (start with Button only).
2. TextBox adapter in phase 2.

Rationale:
1. Button has straightforward Border + ContentPresenter mapping.
2. TextBox requires control-part-aware template shape and should be isolated.

**Mapping Table: Button (ContentControl Adapter)**
1. Control `Padding` -> Content host insets (ContentPresenter margin or equivalent).
2. Chrome `CornerRadius` -> `ButtonChrome` Border corner radius.
3. Chrome `BorderBrush` -> `ButtonChrome` border brush.
4. Chrome `BorderThickness` -> `ButtonChrome` border thickness.
5. Chrome `Background` -> `ButtonChrome` background.
6. Trigger `-Scope Chrome` -> target named part (`ButtonChrome`).

**Error Behavior**
1. If `Chrome` is used with unsupported control type, throw clear validation error.
2. If unsupported property appears in `Chrome`, throw with adapter/property details.
3. If both `Template` and `Chrome` are present in the same style (v1), fail fast with actionable message.

**Testing Requirements**
1. Unit: parse and store Chrome spec in style context.
2. Unit: adapter selection for supported/unsupported types.
3. Unit: property mapping and trigger target mapping.
4. Unit: conflict precedence behavior.
5. Integration: generated style works for Button with hover/pressed/focused states.
6. Regression: existing non-Chrome styles remain unchanged.

**Phased Rollout**
1. Phase 1: internal adapter registry + Button-only Chrome support.
2. Phase 2: TextBox adapter with explicit template-part contract.
3. Phase 3: evaluate broader control families based on usage.

**Migration Guidance**
1. Existing `Template`-based styles continue to work.
2. New styles can adopt `Chrome` incrementally.
3. Advanced cases keep using full `Template` without constraints.

**Open Questions**
1. Should `-Scope Chrome` be required in triggers, or inferred in `ChromeTrigger` block?
2. Should v1 allow `Template` + `Chrome` with merge rules, or keep strict mutual exclusivity?
3. Should fallback inheritance from control scope be opt-in or default?
