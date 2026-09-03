# WPF Designer

> [!WARNING]
> Experimental scaffold. Only a launchable shell window exists so far — no toolbar,
> viewport, or property panel yet.

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
- [ ] Toolbar of draggable controls.
- [ ] Design surface (drop, select, move, resize).
- [ ] Property panel bound to the selected control.
