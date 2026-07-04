# Feature Decision: Grid Cell Explicit Container Requirement

## Summary
When a Grid cell block returns multiple child elements, the author must provide an explicit container instead of relying on a hidden auto-provisioned panel. This keeps layout intent visible, avoids hidden-parent styling issues, and makes debugging clearer when a cell contains more than one object.

## Problem
The current WPF mental model is accurate but not especially friendly for beginners: multiple direct children in the same Grid cell overlap unless the author manually introduces a container. That behavior is unsurprising to WPF veterans, but it is easy for DSL users to misread as "place these controls here in order."

An auto-provisioned container looked attractive at first, but it introduces hidden parentage, styling ambiguity, and indirection when users need to retrieve grid properties or understand where controls live in the visual tree.

## Decision
* A cell block that produces exactly one child attaches that child directly to the cell.
* A cell block that produces more than one child must return an explicit container.
* The recommended container for the common top-to-bottom case is `VStackPanel`.
* The DSL should raise a clear error when multiple children are returned without a container.

## Goals
* Keep the layout tree visible and debuggable.
* Make the rule deterministic and easy to explain.
* Preserve an explicit escape hatch for sequential layout and other container-driven arrangements.
* Provide a clear error when multiple children are returned without a container.

## Non-Goals
* No change to WPF Grid itself.
* No attempt to infer arbitrary layout intent beyond simple stacking.
* No automatic conversion of every nested control block into a panel.
* No change to explicit `StackPanel`, `VStackPanel`, `HStackPanel`, `Grid`, or similar container keywords.

## Error Contract
* If multiple children are returned without an explicit container, fail with a clear message.
* The message should tell the user to wrap the content in `VStackPanel` for the common top-to-bottom case.
* The message should make it clear that the DSL considers the pattern valid only when the container is explicit.

## Recommended Pattern
* Recommended container for the common case: `VStackPanel`.
* Rationale: the most common user expectation for multiple controls in a form is top-to-bottom flow, and the visible container keeps that intent clear.

## Example

```powershell
Grid 'FormGrid' {
    Row {
        Column {
            VStackPanel {
                Label { $this.Content = 'Amount:' }
                TextBox { $this.Text = '1000' }
            }
        }
    }
}
```

With an explicit `VStackPanel`, the `Label` and `TextBox` render in a vertical stack inside the same cell and the layout tree remains visible.

## Rationale
This rule keeps the DSL honest about structure: if the author returns multiple sibling controls from one cell block, the DSL should not guess how to parent them. An explicit container keeps the behavior understandable for beginners and avoids the hidden-parent problems that surfaced during review.

## Considered Options

### Keep current behavior
Maintain raw WPF semantics and require authors to insert a container manually.

### Auto-stack vertically
This was appealing as a beginner-friendly default, but it hides parentage and complicates styling and debugging.

### Auto-provision a generic Grid
This would preserve flexibility but would not actually resolve the overlap problem or reduce cognitive load for new users.

## Consequences
* Simple forms require one extra visible container when a cell has multiple children.
* Styling and tree inspection remain straightforward because the layout hierarchy is explicit.
* Documentation must clearly tell users to wrap multi-child cells in `VStackPanel` or another container.

## Follow-Ups
* The error message should mention `VStackPanel` first because it is the most likely fix for the common form-layout case.
* A future convenience keyword may be considered later, but it must not introduce hidden parentage.
* Overlap remains available only through explicit containers for now.
