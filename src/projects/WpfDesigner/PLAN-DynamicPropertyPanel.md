# WPF Designer — Dynamic Property Panel Plan

Working plan for replacing the property panel's fixed Content/Width/Height fields with a
per-selection generated set of editors, written up for later reference rather than
implemented all at once. Handed off from a design discussion; the next agent picking this
up does not need that conversation's context, only what's captured here.

## Where this picks up from

`Get-WpfDesignerPropertyDescriptor` and `Get-WpfDesignerEditorKind` already exist and are
covered by their own Pester suites:

- `Get-WpfDesignerPropertyDescriptor` wraps `[System.ComponentModel.TypeDescriptor]::GetProperties`
  with a `Browsable(true)` filter, drops anything `IsReadOnly`, and returns
  `Name`/`PropertyType`/`Category`/`EditorKind` for each remaining property — but only for
  properties whose type maps to a known `EditorKind`.
- `Get-WpfDesignerEditorKind` classifies a `[type]` into one of `Text`, `Number`, `Bool`,
  `Enum`, or `$null` (unsupported — e.g. `Brush`, `Thickness`).

**Known caveat when using these:** iterating the `PropertyDescriptorCollection` returned by
`TypeDescriptor.GetProperties` requires calling `.GetEnumerator()` explicitly before
`foreach`— plain `foreach ($x in $Collection)` binds the whole collection to `$x` for a
single silent-failing iteration instead of one `PropertyDescriptor` per pass. See
`Get-WpfDesignerPropertyDescriptor.ps1` for the working pattern; do not "simplify" it back
to a bare `foreach ($Property in $Properties)` in any new code that consumes these cmdlets.

Neither cmdlet is wired into the actual designer UI yet. Today's property panel
(`WpfDesigner.DSL.ps1`, `PropertyPanelContent` `StackPanel`) is three hand-written,
fixed fields — Content, Width, Height — regardless of what's selected. `TextBox` widths use
`Add-WpfDesignerPropertyMinimum` (clamps to a minimum of 20 on `LostFocus`) and
`Add-WpfDesignerEnterCommit` (commits on Enter instead of only on focus loss). This plan
replaces that fixed block with a generated one, driven by the two cmdlets above.

## Why not rebuild the panel by hand per selection

An event-driven rebuild that hand-authors a `TextBlock`/input pair per property on every
selection change scales with *properties on the selected object, every time it's
selected* — not once per control type. The design goal instead is:

- Key rendering off `EditorKind` (a small closed set: `Text`, `Number`, `Bool`, `Enum`, and
  eventually more) rather than per-control-type or per-property blocks, so the amount of
  panel-building code stays flat as more WPF control types gain support, and only grows
  when a genuinely new *kind* of editor is needed.

Caching the descriptor list per `[type]` (so re-selecting the same kind of control skips
reflection) was considered but is **not** part of this plan's scope — reflection cost for a
handful of properties on a single selected element is unmeasured, and it's premature to
design a cache around a cost that hasn't been shown to matter. Ship Slice B calling
`Get-WpfDesignerPropertyDescriptor` fresh on every selection; only add a cache later if
selection is observed to lag, with a profiled reason to point at.

## Scope for this iteration

In scope:

- `Text`, `Number`, `Bool`, `Enum` editor kinds only (matches what
  `Get-WpfDesignerEditorKind` already classifies).
- Single selected element at a time (matches `State.SelectedElement`'s existing shape).
- Regenerating the whole property panel body on selection change/clear.

Out of scope (do not attempt in this pass):

- Attached properties (`Grid.Row`, `Canvas.Left`, `DockPanel.Dock`, etc.). WPF surfaces
  which types an attached property is relevant for via
  `System.Windows.AttachedPropertyBrowsableForTypeAttribute` (and its `...ForChildren` /
  `...WhenAttributePresent` siblings) on the property's static `GetXxx` accessor — but
  consuming that needs the selected element's *parent* as well as the element itself, which
  is a different shape of problem from this plan's per-object descriptor list. Revisit as
  its own slice later.
- `Brush`, `Thickness`, and any other `EditorKind`-less property type. Adding a new editor
  kind is possible but is its own follow-up, not bundled into wiring up the four that
  already exist.
- Category grouping/ordering in the rendered panel (available for free via
  `PropertyDescriptor.Category` whenever it's wanted, but not required for a first pass).

## Relationship to existing code

- `WpfDesigner.DSL.ps1`'s `PropertyPanelContent` `StackPanel` currently declares
  `PropertyContentLabel`/`PropertyContentInput`, `PropertyWidthLabel`/`PropertyWidthInput`,
  `PropertyHeightLabel`/`PropertyHeightInput` directly. These get replaced by a single
  generated host (e.g. an empty child panel that Slice B populates), not extended
  side-by-side with the new mechanism.
- `Add-WpfDesignerPropertyMinimum`'s Width/Height clamp-to-20 behavior has no reflection
  equivalent — `Get-WpfDesignerPropertyDescriptor` doesn't know about it. It needs to
  survive as an explicit override (Slice C), not get silently dropped when the fixed fields
  are removed.
- `Add-WpfDesignerEnterCommit` is control-agnostic (works on any `TextBox`) and should keep
  being reused by any new `Text`/`Number` row, not reimplemented.
- `Select-WpfDesignerElement` and `Clear-WpfDesignerSelection` are the only two places that
  mutate `State.SelectedElement` today — those are the natural call sites for triggering a
  panel rebuild (Slice B), rather than adding a third, separate selection-change path.

## Phased implementation slices

Rough dependency order; each should land with its own tests before the next starts, per
this project's existing Pester conventions (dot-source the functions under test in
`BeforeAll`, `-Tag 'WpfDesigner'`).

### Slice A — Per-`EditorKind` row builders

Add one function per `EditorKind` (or a single function that switches on it — either is
fine, but keep the per-kind logic in one place rather than duplicating it at every call
site) that, given a `PropertyDescriptor`-shaped input (`Name`, `PropertyType`) plus the
target object and `$State`, returns a `Label` + input control pair wired up:

- `Text` → `TextBox`, `BindProperty Text <Name> -TwoWay`, `Add-WpfDesignerEnterCommit`.
- `Number` → same as `Text`, plus the Slice C override hook for clamping.
- `Bool` → `CheckBox`, `BindProperty IsChecked <Name> -TwoWay`.
- `Enum` → `ComboBox`, `ItemsSource = [Enum]::GetValues($PropertyType)`,
  `BindProperty SelectedItem <Name> -TwoWay`.

Tests: one case per `EditorKind` asserting the right control type is produced and that
setting a value through the generated control's binding actually updates the target
object's property (round-trip, not just "a `TextBox` exists").

**Construction note:** these rows are built from a PowerShell function, not authored inline
in a declarative DSL tree, so the plain `TextBox 'Name' { ... }` keyword syntax doesn't apply
here. Follow the same pattern `Add-WpfDesignerControl` already uses for this — call the
keyword function directly with auto-attach suppressed (`& 'TextBox' -AutoAttach $null
{ ... }`) and attach the result with `Add-WPFObject`, rather than relying on ambient
`WPFAutoAttachContext`.

### Slice B — Rebuild panel on selection change

Add an `Update-WpfDesignerPropertyPanel -Panel <parent panel> -State <state>` function that:

1. Clears the panel's current children.
2. If `State.SelectedElement` is `$null`, leaves it empty and returns.
3. Otherwise calls `Get-WpfDesignerPropertyDescriptor -InputObject $State.SelectedElement`
   and, for each descriptor, calls the matching Slice A row builder, appending rows to the
   panel.

Call this from both `Select-WpfDesignerElement` (after `State.SelectedElement` is set) and
`Clear-WpfDesignerSelection` (after it's cleared to `$null`). Update
`WpfDesigner.DSL.ps1`'s `PropertyPanelContent` block to declare the empty host panel instead
of the three fixed fields.

Tests: selecting a `TextBlock` populates rows matching its descriptor list; selecting a
different element type replaces (not appends to) the previous rows; clearing selection
empties the panel.

Note: `TypeDescriptor.GetProperties` doesn't guarantee `Content`/`Width`/`Height`-first
ordering, so the panel's row order will look shuffled relative to today until Slice D's
category grouping (or some ad hoc ordering) lands. Expected, not a bug.

### Slice C — Property override table

A lookup that Slice A's row builders consult for behavior reflection alone can't provide —
the existing Width/Height minimum-20 clamp is the motivating example. Key this primarily by
**property name**, not by concrete `[Type]`: Width/Height are a `FrameworkElement`-level
concern, not specific to `Label` or `StackPanel`, so a `[Type]`-keyed table would need a
duplicate entry for every new control type added to the toolbar — working against the same
flat-not-per-control-type goal `EditorKind` was designed for. Scope narrowly by property type
instead where needed (e.g. "name is Width/Height and the target is a `FrameworkElement`").

Keep this table narrow — additions/behavior tweaks for real gaps, not a general-purpose
allow/deny list re-implementing what `Get-WpfDesignerPropertyDescriptor` already filters.

Tests: a `TextBlock`'s generated Width/Height rows still clamp to 20, matching current
`Add-WpfDesignerPropertyMinimum` behavior; an overridden property shows up with its
override behavior applied instead of (or in addition to) the base row.

### Slice D — Polish (optional, not blocking)

- Group rows by `PropertyDescriptor.Category` instead of a flat list.
- Friendlier `Enum` display (e.g. inserting spaces into `PascalCase` values) instead of raw
  `.ToString()`.

## Open questions / risks

- Should the override table (Slice C) live as data (a hashtable literal) or as small
  per-property functions? A hashtable keeps it inspectable at a glance; functions make
  complex per-property logic (like the existing clamp) easier to express. Lean toward
  hashtable entries whose values are scriptblocks, so both concerns are covered without a
  second mechanism.
- The original design discussion also floated `Window.WindowState` as a Slice C candidate,
  but that doesn't hold up: `WindowState` is a plain enum property that `EditorKind` already
  classifies with no special-casing, *and* `Window` is never itself a selectable
  `State.SelectedElement` in the current app (only `Label`/`StackPanel` instances added via
  `Add-WpfDesignerControl` are selectable). Treat this as stale unless a real reflection gap
  turns up during Slice C.
- `Get-WpfDesignerPropertyDescriptor` currently has exactly one consumer once this plan
  lands (this panel). If a second consumer shows up later, revisit whether the raw
  reflection layer (not the `EditorKind` opinion) belongs in the WPF module instead of this
  project — see the design-discussion note already captured in this repo's session history
  for the reasoning, but do not treat that as settled unless a real second consumer appears.
