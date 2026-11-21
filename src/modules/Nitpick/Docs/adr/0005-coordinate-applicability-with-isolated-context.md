---
status: accepted
---

# Coordinate Rule Applicability with Isolated Context

Rules declare optional context-only applicability predicates, enforced by the
coordinator through descriptor invocation rather than producer early returns,
so inapplicability is distinguishable from execution without findings and from
an unsupported analysis host. Predicates and producers each receive recursively
isolated plain-data context copies, keeping project policy separate from target
identity and invocation metadata, because read-only dictionary storage does not
prevent PowerShell ETS shadowing or isolate nested mutable values. This protects
against accidental cross-execution state leaks, not arbitrary rule code; see
[the design proposal](../ProjectPolicyAndRuleApplicability.md) for the agreed
contracts and deferred work.
