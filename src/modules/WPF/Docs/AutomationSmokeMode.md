## Automation Smoke Mode

When running WPF applications in unattended automation (for example, agent validation or CI), set `WPF_SMOKE_TEST` so modal windows close automatically after first render.

Accepted enabled values: `$true`, `1`, `true`, `yes`, `on`.

PowerShell example:

```powershell
$env:WPF_SMOKE_TEST = $true
./Examples/ImageViewer/ImageViewer.DSL.ps1
$env:WPF_SMOKE_TEST = $false
```
