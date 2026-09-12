# WPF Designer

> [!WARNING]
> Experimental scaffold. Labels can be added, dragged, selected, resized, and edited via
> the property panel, with committed edits validated. The design can be exported as
> runnable DSL script text. See Status for full detail.

A visual designer for the [WPF DSL](../../modules/WPF), built as a consumer of its public
API rather than as part of the module itself. Scope for v1 is intentionally narrow:

- Place a `Window` and `Label` controls on a design surface.
- A toolbar of available controls.
- A property panel exposing basic properties (e.g. `Width`/`Height`) for the selected control.

This project lives under `src/projects` instead of `src/modules/WPF` so it can iterate quickly
without affecting the module's release lifecycle, docs, or exported keyword surface. It only
depends on the WPF module's public commands and DSL keywords.

## Run

```powershell
./WpfDesigner.DSL.ps1
```

## Status

- [x] Scaffold: entry script launches a bare window.
- [x] Shell layout: toolbar / viewport / property panel panes.
- [x] Toolbar action to add Labels onto the design surface (click-to-place).
- [x] Move placed Labels by dragging (`Canvas` + `Draggable`).
- [x] Placed Labels have a visible border and a hover highlight (`Style Label`).
- [x] Selection of a placed Label (click to select, click empty canvas to deselect).
- [x] Resize handle for the selected Label (bottom-right corner, 20px minimum).
- [x] Dynamic property panel with two-way text, numeric, boolean, and enum editors.
- [x] Boolean properties use compact inline checkbox labels.
- [x] Unbounded numeric values such as `MaxWidth` display and accept `None`.
- [x] Attached properties are omitted until parent-aware editing is supported.
- [x] Panel Width/Height edits clamp to the resize handle's 20px minimum on commit.
- [x] Panel fields commit on Enter without requiring focus loss.
- [x] Export the design as runnable DSL script text, copied to the clipboard
  (`ConvertTo-WpfDesignerScript`).
- [x] Abstract Window frame on the canvas: a resizable/selectable `Border` standing in for
  the exported `Window`'s bounds (`New-WpfDesignerWindowFrame`, PLAN.md Slice A).
- [x] Window proxy properties: selecting the frame edits an associated hidden `Window`,
  with two-way `Width`/`Height` binding to the frame and a default child `Canvas` for
  freely positioned controls.

The proxy frame uses `Window.Width` and `Window.Height` as its visual dimensions. This is
an intentional approximation for the experimental designer: a rendered top-level Window's
client area can differ because its dimensions include non-client chrome.

## Todo

Nothing outstanding.
- Consider a way to avoid DataContext null warning when intentional. 
