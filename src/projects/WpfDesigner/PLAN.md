# WPF Designer — Container-Aware Editing Plan

Working plan for the next iteration of the designer, written up for later reference rather
than implemented all at once. Scope is deliberately small: get the *mechanics* of
container-aware editing right with the fewest possible control types before adding breadth.

## Where this picks up from

Phases 0–6 (scaffold, shell layout, toolbar, selection/resize, property panel, panel
validation, DSL export) are done and covered by the `WpfDesigner` Pester suite. That work
assumed a single flat model: one `Canvas`, `Label` children placed on it by absolute
`Canvas.Left`/`Top`, nothing nested.

This plan replaces that flat model with a real container hierarchy, while keeping the
canvas as the free-form *authoring surface* (not the exported output's root panel).

## Controls in scope for this iteration

- `Window` — represented on the canvas as an abstract frame (see constraint below), not a
  literal `Window` instance.
- `StackPanel` — the only container type for now.
- `Label` — the only leaf control type for now.

Everything else (other panels, other controls, undo/redo, multi-select, snapping/alignment
guides) is explicitly out of scope until this shape proves out.

## Technical constraint: `Window` can't be embedded

WPF's `Window` class is always top-level; it cannot be a visual child inside another
element's tree. The on-canvas representation is therefore a styled `Border` proxy. An
unshown `[System.Windows.Window]` associated with that proxy supplies authentic Window
properties to the dynamic property panel and exporter. `Width` and `Height` are bound
two-way between the objects; this intentionally approximates the rendered client area
because top-level Window dimensions include non-client chrome.

## Target authoring model

- The `Canvas` hosts zero or more design-time roots:
  - Exactly one abstract Window frame (a resizable `Border` standing in for the exported
    `Window`'s bounds). Its child is a default `Canvas` content root for free placement.
  - Any number of "loose"/floating elements or subtrees not currently parented to anything.
- Toolbar buttons are selection-sensitive:
  - If a container-capable element is selected (the Window frame, or a `StackPanel` already
    placed), clicking a control button adds the new control as a real child of that
    selection.
  - If nothing is selected, or the selection isn't a valid container, the new control spawns
    loose on the canvas instead of failing or guessing a target.
- An element (or a whole subtree, e.g. a `StackPanel` with `Label` children) can be detached
  from its container and become loose on the canvas again, fully formed, until dragged into
  a (new) container.
- Export walks the real tree recursively (Window frame → nested containers → leaf controls),
  not a flat `Canvas.Children` list.

## Relationship to existing code

Most of Phases 3–4's code assumed a flat `Canvas.Children` collection of `Label`s and will
need real rework, not just extension:

- `Add-WpfDesignerLabel` becomes a special case of a general "create control of type X"
  path (Slice B) instead of its own function.
- `Select-WpfDesignerElement` / `Clear-WpfDesignerSelection` gain container-vs-leaf
  awareness (Slice C) — selecting a `StackPanel` needs to behave differently from selecting
  a `Label` for the purposes of toolbar actions, even though the visual selection/resize
  handle behavior can likely stay the same.
- `ConvertTo-WpfDesignerScript` needs to walk arbitrary nesting instead of a flat list
  (Slice E) — the current flat-list assumption is baked into its loop.
- The resize `Thumb` / `Draggable -BoundToParent` mechanics should keep working as-is for
  any selected element, container or leaf; nesting shouldn't change how an individual
  element is moved/resized once it's already placed.

## Phased implementation slices

Rough dependency order; each should land with its own tests before the next starts.

### Slice A — Abstract Window frame on the canvas (done)

Replace "the `Canvas` is the whole design surface" with "the `Canvas` hosts a Window frame,
among other things." The frame is a resizable `Border` (reuse the existing resize `Thumb`
mechanics) that represents the exported `Window`'s bounds. Nothing can be placed "outside"
it conceptually, but loose elements can still sit elsewhere on the canvas.

### Slice B — Generalize control creation (done)

Turn `Add-WpfDesignerLabel` into a general "add control of type `X`" path so `StackPanel`
isn't a one-off copy-pasted function. Toolbar gains a second button. No placement-target
logic yet — new controls still land in a fixed default spot (this slice is just about not
duplicating creation code per control type).

Landed as `Add-WpfDesignerControl` (shared placement/selection/drag/resize wiring, taking a
`-Type` name and a `-Configure` scriptblock for type-specific defaults), with
`Add-WpfDesignerLabel` and `Add-WpfDesignerStackPanel` as thin per-type wrappers. Along the
way, selection highlighting was reworked from mutating the target's own
BorderBrush/BorderThickness (which `StackPanel`, a bare `Panel`, doesn't have) to a separate
non-hit-testable `Border` overlay (`New-WpfDesignerSelectionOutline`) positioned over the
target — the same sibling-overlay approach already used for the resize handle. This makes
selection work uniformly for any future control/container type regardless of what DPs it
exposes.

### Slice C — Container-aware placement (done)

Make control creation selection-sensitive: child-of-selection when the selection is a valid
container (Window frame or `StackPanel`), floating-on-canvas otherwise. This is where
`Select-WpfDesignerElement` needs to distinguish container-capable selections from leaf
selections.

Landed as a PSTypeName marker (`Custom.WpfDesigner.Container`, via
`Add-PSType`/`Test-PSType`) rather than a hardcoded type
list — scoped to this project since the WPF module's own `Custom.WPF.*` marker system
(`Add-WPFType`/`Test-WPFType`) is closed to a fixed `ValidateSet`. `Add-WpfDesignerControl`
checks the current selection against the marker plus `Test-WpfDesignerContainerCapacity`
(a `Border` only has one `Child` slot; a `Panel` like `StackPanel` doesn't) before deciding
whether to nest the new element via `Add-WPFObject` or fall back to floating on the canvas.
The Window frame redirects placement to its default child `Canvas`, preserving free-form
dragging while the proxy remains the selectable representation of the Window itself.

Nesting exposed a real gap in the resize-handle/selection-outline overlay math: both were
positioned via `Canvas.GetLeft/Top` on the target, which is meaningless once the target's
actual parent is a `StackPanel` instead of the `Canvas`. `Get-WpfDesignerCanvasRelativePosition`
now resolves a target's position relative to the root `Canvas` via `TransformToVisual` for
non-Canvas-parented targets (requires a completed layout pass, same caveat as
`ActualWidth`/`ActualHeight` elsewhere in this project), falling back to the existing fast
path for direct canvas children. `Draggable` already refuses to drag anything whose
`.Parent` isn't literally a `Canvas` (silent warn + no-op), so nested children are
resize-only for now — reordering children within a container by dragging (the `StackPanel`
equivalent of free positioning) is out of scope here and would need its own slice if wanted
later.

### Slice D — Detach-to-floating

Let a selected element (or its whole subtree) be pulled back out of its current container
and become loose on the canvas again, at its last known position, still fully formed. Keep
this deliberately incremental: explicit reparenting comes first; drag-to-reparent and a
full Visual Studio-style tree are follow-up interaction layers, not prerequisites.

#### D1 — Make nested selection reliable (done)

Controls created by `Add-WpfDesignerControl` already receive their own selection handler,
even when nested. The current failure is routed-event handling: a nested child's
`Draggable` handler rejects its non-`Canvas` parent without marking the mouse event handled,
so the event continues to its containing `StackPanel`, whose handler replaces the child
selection with the parent selection.

Stop that designer-created ancestor bubbling after the nested child has selected itself,
without changing the WPF module's general `Draggable` behavior. Prove separately that a
nested `Label` and nested `StackPanel` can be selected, that the property panel follows the
child selection, and that clicking a container outside one of its children still selects
the container.

Landed in `Add-WpfDesignerControl`: its selection handler now marks the routed mouse event
handled when the element's immediate parent is not a `Canvas`. Direct `Canvas` children
still leave the event available for `Draggable`, while nested children retain their own
selection instead of allowing an ancestor container to replace it. Routed-event tests cover
nested `Label` selection plus property-panel refresh, nested `StackPanel` selection, and a
direct click on the outer container.

Selection should continue to use the existing outline and resize thumb. Nested controls
are not draggable while parented to a `StackPanel`, but they remain resizable; replacing
the resize thumb with a detach affordance would unnecessarily discard that capability.

#### D2 — Add one reparenting primitive (done)

Implement an approved-verb command named `Move-WpfDesignerElement`. "Detach" remains the
clear user-facing label, but does not need to be the PowerShell function name (and therefore
does not require an alias solely to avoid `Import-Module` approved-verb warnings). Design
the command around a target container rather than around "detach" specifically so the same
primitive can later support moves initiated from a visual tree.

For the first increment, the supported move is from a nested container to the root design
`Canvas`. It should perform the operation in this order:

1. Validate the source and target before mutating either tree. Reject the Window frame,
  design-time overlays, an already-floating element, and any unsupported target.
2. Capture the selected element's root-canvas-relative position with
  `Get-WpfDesignerCanvasRelativePosition` while it is still in the laid-out visual tree.
3. Clear selection so the root-canvas outline and thumb are removed and their
  `SizeChanged` handlers are unsubscribed before the element moves.
4. Remove the element from its actual parent through a small parent-shape-aware helper
  (`Panel.Children.Remove`, or clearing a matching single-content slot such as
  `Border.Child`). Do not remove or rebuild the element's descendants.
5. Add the same element instance to the root design `Canvas`, restore the captured position
  through `Canvas.Left`/`Canvas.Top`, and select it again. Its existing `Draggable` handlers
  resolve the parent at drag start, so they should become active automatically once the
  parent is a `Canvas`.

The move must be effectively transactional: validation happens before removal, and a
failed target insertion must restore the element to its original parent and position/order
rather than leave it unparented. The first implementation need not expose arbitrary target
containers, but its parameter and validation shape should not prevent that extension.

Tests for this increment:

- A nested `Label` becomes a direct root-`Canvas` child at the same visual position and is
  selected and draggable afterward.
- A nested `StackPanel` moves as one intact subtree; its child object identities and order
  are unchanged. Moving the subtree root is ordinary WPF reparenting, not a recursive
  detach operation.
- Detaching from both a `Panel` and a single-child host is covered.
- Invalid moves make no tree or selection changes.
- Selection overlays remain design-surface children and no event handlers or overlays are
  leaked across the move.

Landed as `Move-WpfDesignerElement`, with an extensible `FrameworkElement` target parameter
and an explicit first-slice restriction to a `Canvas` target. It validates before mutation,
captures root-canvas coordinates, clears and recreates selection chrome, handles both
`Panel.Children` and `Decorator.Child` source shapes, and restores the original parent,
sibling index, and selection if destination insertion fails. Existing `Draggable` handlers
become active after the move because they resolve the current parent when dragging starts.
Focused tests cover position preservation, fresh non-leaking overlays, drag reactivation,
intact subtree identity/order, both source shapes, rejected moves, and forced rollback.

#### D3 — Expose an explicit Detach command

Add a `Detach` button beside the property panel or other selected-element actions. Enable
it only when the current selection is a movable nested element; disable it for the Window
frame, overlays, and elements already on the root design `Canvas`. The button invokes
`Move-WpfDesignerElement` and refreshes any structure-dependent UI after a successful move.

This explicit command is the Slice D interaction. It avoids overloading the resize thumb
and establishes deterministic reparenting behavior before drag/drop introduces hit testing
and cancellation paths.

#### Follow-up — Visual tree and direct reparenting

`Get-WpfDesignerElementTree` already supplies a recursive, depth-annotated hierarchy and
filters design-time overlays, so a visual-tree pane would not start from zero. A first pane
can rebuild after structural changes, synchronize its selected row with
`State.SelectedElement`, and offer context-menu commands such as `Detach` and later
`Move to <container>`. It should preserve expansion and selection state across refreshes.

Once that selection surface is useful, extend `Move-WpfDesignerElement` to accept marked
containers, resolve the Window frame to its `_WPFDesignerContentRoot`, call
`Test-WpfDesignerContainerCapacity`, and preserve `StackPanel` insertion order. This is a
controlled second route to reparenting without requiring pointer drag/drop.

Direct drag-to-reparent remains deferred. It requires drop-target hit testing and
highlighting, container-capacity validation, `StackPanel` insertion semantics, coordinate
conversion, and rollback when a drop is invalid. Those concerns should build on the tested
move primitive rather than be implemented at the same time as it.

### Slice E — Recursive export

Update `ConvertTo-WpfDesignerScript` to walk the real Window-frame → container → leaf tree
instead of a flat list, emitting nested DSL blocks that match the actual hierarchy.

### Slice F — `AstEditor`-backed import/export (deferred)

Replace the naive string-templating export (and add a matching import) with
`src/modules/AstEditor` so DSL source can be parsed into the design-time model and
regenerated/patched from it, instead of always emitting a fresh throwaway script. Explicitly
future work — not started until A–E are solid.

## Open questions / risks

- How are floating elements visually distinguished from ones inside the Window frame, so
  it's obvious at a glance what will and won't be in the export?
  - Elements should only be allowed to float on the canvas where there is clear separation from the main window. Dragging a label out of a stackpanel onto the window (canvas really) would just add it to the Window or in the event the Window was an invalid target, the operation would be canceled and the element returned to the StackPanel.
- What counts as a "valid container" for placement purposes as more control types are added
  later — likely needs an explicit marker (compare to the WPF module's own
  `Custom.WPF.CollectorOwner` pattern for collector-owner keywords) rather than a hardcoded
  type check list, so it doesn't need revisiting every time a new container type is added.
  - Resolved in Slice C: a project-scoped `Custom.WpfDesigner.Container` PSTypeName marker
    (`Add-PSType`/`Test-PSType`), not the WPF module's own
    marker system.
- Multi-level detach (pulling a `StackPanel` with `Label` children out as one unit) needs its
  subtree to move together — worth an explicit test once Slice D lands.
  - Resolved in the Slice D plan: move the subtree root as the same object. WPF retains its
    descendants, so no recursive reconstruction is needed; tests should verify identity and
    child order.
