---
status: accepted
---

# Keep PSScriptAnalyzer Compatibility in a Separate Adapter

Nitpick producers, helpers, and finding/correction types now use only the native
`NitpickFinding` and `NitpickCorrection` contracts. The optional
`Nitpick.ScriptAnalyzer` module discovers built-in Nitpick descriptors and
generates PSScriptAnalyzer wrappers at import time, so a separate module owns
`DiagnosticRecord` and `CorrectionExtent` conversion.

This boundary keeps PSScriptAnalyzer out of ordinary Nitpick debugging and test
execution while retaining PSScriptAnalyzer hosting for users who need it. The
adapter exports findings but omits multi-edit corrections because
PSScriptAnalyzer cannot preserve Nitpick's atomic whole-fix semantics.
`Nitpick.psd1` is intentionally no longer a compatible `-CustomRulePath`;
consumers point that parameter at `Nitpick.ScriptAnalyzer.psd1` instead.
