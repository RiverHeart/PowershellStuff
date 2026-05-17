## Automation Smoke Mode

When running WPF applications in unattended automation (for example, agent validation or CI), set `WPF_AUTO_CLOSE_SECONDS` to control window auto-close behavior after first render.

If your app exposes `AutoCloseSeconds`, that value is preferred and starts counting after first render (`ContentRendered`). Set `AutoCloseSeconds` or `WPF_AUTO_CLOSE_SECONDS` to `0` to close immediately after first render while still exercising startup/render path.

PowerShell example:

```powershell
$env:WPF_AUTO_CLOSE_SECONDS = '0'
./Examples/ImageViewer/ImageViewer.DSL.ps1
Remove-Item Env:WPF_AUTO_CLOSE_SECONDS -ErrorAction SilentlyContinue
```
