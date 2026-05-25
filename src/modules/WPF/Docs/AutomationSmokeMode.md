## Automation Smoke Mode

When running WPF applications in unattended automation (for example, agent validation or CI), set `WPF_AUTO_CLOSE_SECONDS` to control window auto-close behavior after first render.

This environment fallback applies both to DSL-created `Window` instances and to direct windows passed to `Show-WPFWindow`.

If your app exposes `AutoCloseSeconds`, that value is preferred and starts counting after first render (`ContentRendered`). Set `AutoCloseSeconds` or `WPF_AUTO_CLOSE_SECONDS` to `0` to close immediately after first render while still exercising startup/render path.

For unattended tests, make sure the window has renderable content such as a child control or direct `Content`; otherwise `ContentRendered` may not fire and the auto-close policy will not start.

PowerShell example:

```powershell
$env:WPF_AUTO_CLOSE_SECONDS = '0'
./Examples/ImageViewer/ImageViewer.DSL.ps1
Remove-Item Env:WPF_AUTO_CLOSE_SECONDS -ErrorAction SilentlyContinue
```
