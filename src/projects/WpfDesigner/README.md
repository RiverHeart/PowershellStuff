# WPF Designer

> [!WARNING]
> Experimental scaffold. Labels can be added, dragged, selected, and resized, but there's
> no property panel binding yet.

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
- [ ] Property panel bound to the selected Label.
