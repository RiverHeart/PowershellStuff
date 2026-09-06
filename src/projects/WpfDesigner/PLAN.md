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
element's tree. So "a window rendered on the canvas" cannot literally be a live `Window`
instance sitting inside the `Canvas`. The on-canvas representation must be an abstract
stand-in — a styled `Border` acting as window chrome, resizable within the canvas — that the
designer treats as "the Window" for authoring purposes. A real `[System.Windows.Window]`
only materializes at export/preview time. This is the same approach visual designers like
Blend/Visual Studio use.

## Target authoring model

- The `Canvas` hosts zero or more design-time roots:
  - Exactly one abstract Window frame (a resizable `Border` standing in for the exported
    `Window`'s bounds).
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

### Slice B — Generalize control creation

Turn `Add-WpfDesignerLabel` into a general "add control of type `X`" path so `StackPanel`
isn't a one-off copy-pasted function. Toolbar gains a second button. No placement-target
logic yet — new controls still land in a fixed default spot (this slice is just about not
duplicating creation code per control type).

### Slice C — Container-aware placement

Make control creation selection-sensitive: child-of-selection when the selection is a valid
container (Window frame or `StackPanel`), floating-on-canvas otherwise. This is where
`Select-WpfDesignerElement` needs to distinguish container-capable selections from leaf
selections.

### Slice D — Detach-to-floating

Let a selected element (or its whole subtree) be pulled back out of its current container
and become loose on the canvas again, at its last known position, still fully formed.

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
  - The solution to this should be discussed with the user.
- Multi-level detach (pulling a `StackPanel` with `Label` children out as one unit) needs its
  subtree to move together — worth an explicit test once Slice D lands.
  - This seems like a big lift, if it seems that a lot of effort would be required, this should only be attemped after all the low hanging fruit has been plucked.
