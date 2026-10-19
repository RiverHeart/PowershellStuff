---
status: accepted
---

# Defer PSScriptAnalyzer Compatibility to a Future Adapter

Every native Nitpick rule function today accepts `$Context.RuleBehavior` and conditionally
emits either `NitpickFinding` or `DiagnosticRecord` output, so the same function also works
directly as a PSScriptAnalyzer `-CustomRulePath` rule. Making rule identity (`RuleId`,
`RuleName`, `RuleSuppressionID`) coordinator-assigned rather than producer-supplied exposed
that this dual-mode contract couples rule authoring to PSScriptAnalyzer's shape: a producer
function invoked directly by PSScriptAnalyzer has no coordinator available to supply identity,
so it must keep self-deriving it in that mode regardless of what the native path does.

We will not build a Nitpick-to-PSScriptAnalyzer adapter now, and will not change the current
dual-mode rule-authoring contract as part of qualified-identity work (RulePackages.md Phase 5).
Direct PSScriptAnalyzer `-CustomRulePath` compatibility is explicitly de-emphasized as a
first-class design constraint going forward. If broader compatibility is still wanted later,
it should be achieved through a separate adapter/conversion layer rather than requiring every
rule body to understand both output shapes.

PSScriptAnalyzer also cannot be invoked from within the PowerShell extension for VS Code,
making it significantly harder for users to debug a rule interactively compared to running it
natively through Nitpick. This gap only grows more important once Nitpick starts populating a
larger set of default/built-in rules, since those are exactly the rules most users will want
to step through locally.

## Consequences

- Existing rule files keep their current dual-mode code unchanged for now; new rules are not
  required to support `-CustomRulePath` directly.
- This mirrors the companion decision to drop suppression rename-compatibility: both accept a
  known, documented interop cost now in exchange for a simpler, more consistent identity model,
  rather than solving every external-compatibility edge case immediately.
- Test coverage for PSScriptAnalyzer-hosted suppression behavior is not maintained alongside
  the native identity work; native `Start-Nitpicking` does not implement suppression-checking
  at all today, and that remains a separate, deferred suppression-semantics decision.
