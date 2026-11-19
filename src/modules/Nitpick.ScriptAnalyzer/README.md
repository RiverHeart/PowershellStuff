# Nitpick.ScriptAnalyzer

`Nitpick.ScriptAnalyzer` is the optional PSScriptAnalyzer adapter for Nitpick's
built-in rules. It discovers the built-in Nitpick descriptors, generates
PSScriptAnalyzer-compatible rule commands at module import, and converts native
`NitpickFinding` output into `DiagnosticRecord` output.

Run it by passing the adapter manifest to PSScriptAnalyzer:

```powershell
Invoke-ScriptAnalyzer `
    -Path .\Example.ps1 `
    -CustomRulePath .\Nitpick.ScriptAnalyzer.psd1
```

Nitpick itself does not require or load PSScriptAnalyzer. `Nitpick.psd1` is not a
PSScriptAnalyzer `CustomRulePath`.

PSScriptAnalyzer can represent only one source edit per suggested correction.
The adapter exports single-edit Nitpick corrections and omits multi-edit
corrections rather than splitting an atomic Nitpick fix.
