# Nitpick

Nitpick is this repository's PowerShell linting/autocorrection engine: rule authors contribute
checks that inspect parsed script ASTs, and a coordinator selects, executes, and attributes
them consistently regardless of where a rule's backing code lives.

## Language

**Rule**:
A single check, backed by either a PowerShell command or a scriptblock, that inspects a
ScriptBlockAst and reports findings.
_Avoid_: Check, linter, analyzer (reserve "analyzer" for PSScriptAnalyzer specifically)

**Coordinator**:
Nitpick's own orchestration layer (discovery, registration, selection, and execution) that
owns a rule's identity. The coordinator assigns identity; a rule's own code never supplies
or overrides it.
_Avoid_: Engine, runner

**Producer**:
A rule's own callable body (the function or scriptblock an author writes) that generates
findings and corrections. A producer never determines its own identity; it only supplies
finding content (message, severity, corrections).
_Avoid_: Rule author's code (reserve "callable" for the underlying PowerShell object itself)

**Namespace**:
The logical owner of a rule's identity: the declaring package's module name, or `Local` for
a rule registered without an owning package.
_Avoid_: Package name, module name (reserve those for the underlying PowerShell module concept)

**Local Name**:
A rule's canonical identifier within its namespace (for example `UseIsNotOperator`), assigned
once by the coordinator at discovery or registration time. The `RuleName` and
`RuleSuppressionID` properties on a finding both carry this exact value — they are not
independent, producer-supplied identities, and a rename of a rule's backing command or
registration changes both at once with no compatibility alias.
_Avoid_: Display name, suppression ID (as if these were separate from Local Name)

**Rule ID**:
A rule's fully qualified identity: `Namespace/Local Name` (for example `WPF/AvoidBlockingUI`).
Used for selection, the registry key, and conflict/attribution across native findings.
_Avoid_: Qualified name, full name
