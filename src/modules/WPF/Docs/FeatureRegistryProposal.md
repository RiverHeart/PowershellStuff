**Feature Proposal: Opt-In WPF Feature Registry**

**Summary**
Introduce an opt-in feature system for the WPF DSL that lets users enable reusable behaviors (like fullscreen helpers and cursor auto-hide) without requiring them to manually define every state property. This improves discoverability and ergonomics while avoiding hidden global runtime magic.

**Problem**
Users rebuilding common behaviors from scratch need to remember internal state keys and wiring details (timers, handlers, cleanup). Fully implicit state creation across the DSL would be convenient, but risky due to hidden behavior and key collisions.

**Goals**
1. Make common behaviors easy to adopt from scratch.
2. Keep behavior explicit and discoverable.
3. Prevent state key conflicts across features.
4. Keep feature activation and teardown idempotent.
5. Preserve existing DSL behavior unless users opt in.

**Non-Goals**
1. No global automatic state injection for all controls/windows.
2. No breaking changes to existing scripts that do not use features.
3. No mandatory new keyword in initial version.

**Proposed Design**
1. Add an explicit feature layer with register/enable/disable lifecycle.
2. Scope feature state under a namespaced bag on Tag, for example:
   1. Tag.Features.MouseIdleHide.Timer
   2. Tag.Features.MouseIdleHide.Handler
3. Each feature owns:
   1. EnsureState
   2. Enable
   3. Disable
   4. Dispose
4. All lifecycle operations are safe to call repeatedly (idempotent).

**Initial API (Cmdlet-First)**
1. Register-WPFFeature
2. Enable-WPFFeature
3. Disable-WPFFeature
4. Unregister-WPFFeature (optional in v1, useful for cleanup semantics)

**Why Cmdlet-First**
1. Lower risk than introducing a new DSL keyword immediately.
2. Easy discovery with built-in PowerShell tooling.
3. Faster iteration on naming and lifecycle contracts.
4. Straightforward testing before adding syntax sugar.

**Potential DSL Sugar (Future)**
If adoption is good, introduce an optional DSL block that delegates to cmdlets:
1. Features
2. Use <FeatureName> with options

This keeps syntax friendly while preserving explicit opt-in semantics.

**Candidate Built-In Features (Phase 1)**
1. Mouse idle cursor auto-hide in fullscreen
2. Fullscreen window lifecycle helper (enter/exit behaviors, state restore)

**Conflict and Safety Model**
1. Feature state must be namespaced under Tag.Features.<FeatureName>.
2. Feature names must be unique.
3. Register should fail clearly on duplicate name unless Force is specified.
4. Enable/Disable should no-op safely when already enabled/disabled.

**Migration Story**
1. Existing scripts continue unchanged.
2. Scripts can incrementally replace ad hoc state and handlers with feature registration.
3. No required refactor for current Tag state unless users adopt features.

**Testing Requirements**
1. Register creates namespaced feature state only.
2. Enable wires behavior once even if called multiple times.
3. Disable unwires and restores expected UI state.
4. Dispose removes handlers/timers and prevents leaks.
5. No interference between multiple registered features.

**Expected Outcome**
Users get easier startup ergonomics and reusable batteries-included behavior, while the DSL retains explicitness, stability, and long-term maintainability.
