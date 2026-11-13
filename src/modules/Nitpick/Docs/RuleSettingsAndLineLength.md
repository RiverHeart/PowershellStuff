# Rule Settings and Line Length

## Status and scope

Implementation record for rule-specific project settings and the detection-only
line-length rule. The feature extends the existing explicit
`Start-Nitpicking -ConfigurationPath` entry point rather than adding a second
configuration file or automatic discovery. Runtime behavior and user-facing
configuration are documented in the [Nitpick README](../README.md).

The existing [project policy plan](ProjectPolicyAndRuleApplicability.md)
describes the plain-data context, descriptor invocation, snapshot, and
correction contracts this work must preserve. The `Nitpick.psd1` module
manifest and a project configuration conventionally named `nitpick.psd1` are
different files; selecting the latter remains explicit.

## Agreed behavior

### Project configuration and rule declarations

Project settings are grouped by qualified rule ID. This is an illustrative
shape; names remain provisional until the public API is finalized:

```powershell
@{
    Compatibility = @{
        PowerShell = @{ MinimumVersion = '5.1' }
    }
    Rules = @{
        'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 }
    }
}
```

Rules declare their own settings schemas. Both command-backed rules through
`-Details` and scriptblock rules through descriptor creation and registration
can declare them. Start with integer settings, defaults, and range constraints;
do not build a general-purpose validation language before a rule needs it.
An illustrative declaration for the first rule is:

```powershell
Settings = @{
    MaximumLength = @{
        Type = 'Integer'
        Default = 120
        Minimum = 1
    }
}
```

The coordinator validates configured rule IDs and settings against descriptors
before processing targets. Unknown IDs, including rules from packages not
available to the invocation, are errors. Settings for a known rule are validated
even if that rule is excluded from a particular run. Reject misspelled setting
names and invalid values explicitly; do not silently ignore or coerce them into
success-shaped defaults.

Each predicate and producer sees only its own validated effective settings in
`Context.RuleSettings`, including defaults. Apply the existing recursive
plain-data isolation contract: mutation by one predicate or producer must not
affect its counterpart, other rules, other targets, candidate analysis, or
caller-owned values. Initial and candidate analysis use equivalent settings.
Predicates remain subject to the existing single-evaluation, suppression, and
host-prerequisite ordering.

### Line-length rule

The new rule is enabled through ordinary selection, including default selection
when no configuration file is supplied. Its maximum defaults to 120 and can be
overridden with a positive integer. A line exactly at the limit passes; a line
above it produces one Warning finding and no correction.

- Measure the physical line as written, including trailing whitespace.
- Count UTF-16 code units; a tab counts as one unit. Do not expand tabs into
  display columns or depend on editor settings.
- Check all physical lines, including comments and multiline string or
  here-string content.
- For a fragment that begins or ends mid-line, measure the complete physical
  snapshot line if it intersects the fragment; anchor its finding inside the
  submitted fragment. Text outside the fragment can therefore contribute to
  a warning.
- Preserve snapshot coordinates and source provenance. Define and test line
  endings, empty lines, final unterminated lines, and fragment intersection
  at boundaries without counting newline characters toward the limit.

The default-on rule intentionally changes finding output for overlong lines even
without configuration. Call this out in release-facing documentation and test
that existing rule selectors and suppression continue to work.

### Trailing whitespace and rule ordering

[Measure-AvoidTrailingWhitespace](../Public/Rules/Test-AvoidTrailingWhitespace.ps1)
and the new rule analyze the same original snapshot independently. No dependency
or rule ordering is required. With a 120-unit limit, a line of 118 units plus
three trailing spaces initially triggers both rules. If the whitespace
correction is selected and succeeds, candidate reanalysis sees the 118-unit
line and its effective findings no longer include the line-length warning.
Original finding counts can still include that warning. If the correction is not
applied or cannot be applied, reporting must follow the existing correction
workflow rather than pretending the original source was trimmed.

Scanning the snapshot separately is acceptable initially; measure performance
before considering a shared line index or other optimization. Rules must still
work independently when the whitespace rule is not selected.

## Integration work

1. **Configuration and schemas.** Extend the strict configuration parser without
   breaking the existing `Compatibility` policy or its version normalization.
   Keep project rule settings and project compatibility policy distinct in the
   internal representation. Validate data-only schema shape, defaults, ranges,
   IDs, case-insensitive duplicates, and unsupported keys with stable,
   actionable terminating errors. Retain the existing plain-data value limits.
2. **Descriptors and discovery.** Extend `NitpickRule`, `New-Nitpick`, and
   `Register-Nitpick` to carry schema metadata. Preserve metadata through
   discovery, registration precedence, reconstruction, unrelated overrides,
   and explicitly cleared versus omitted metadata, consistent with existing
   applicability metadata. Do not execute rule predicates during discovery.
3. **Known versus selected rules.**
   [Resolve-NitpickEffectiveRuleSet](../Private/Resolve-NitpickEffectiveRuleSet.ps1)
   currently passes `IncludeRule` into `Find-Nitpick` before applying exclusions.
   Validating settings for known but unselected package rules therefore
   requires access to the invocation's known descriptors before selection.
   Preserve existing selector errors, registered-over-discovered precedence,
   callable identity conflicts, module acquisition, and selected-rule totals;
   don't accidentally turn an excluded conflicting rule into a new failure.
4. **Invocation lifecycle.** Resolve each descriptor's effective settings
   before applicability, and supply separate context copies to predicate and
   producer. Wire project settings through original and candidate dispatch and
   the direct correction resolver. Validate direct descriptor input against the
   same schema rather than accepting invalid values. Keep whole-target
   suppression and candidate re-enablement behavior intact.
5. **Rule and documentation.** Implement the rule as an AstDocument-backed
   rule using snapshot coordinates and normal standalone and descriptor output
   conventions. Add it to the manifest export and lint-rule lists. Document
   configuration, rule-author schema declaration, context access, direct-call
   behavior, validation failures, line measurement, and the default-on behavior.

## Resolved implementation contracts

- Direct descriptor callers supply overrides in `Context.RuleSettings`.
  Direct correction resolution uses `-RuleSettings`, keyed by qualified rule
  ID, when more than one descriptor is supplied. The resolver rejects combining
  those two input forms or applying one context settings dictionary to multiple
  descriptors. Every `-RuleSettings` ID must match a supplied rule, so
  `Start-Nitpicking` forwards only the settings for rules that apply to the
  current target.
- A settings map's shape (valid, case-distinct rule IDs mapping to settings
  dictionaries) is checked in one helper, `ConvertTo-NitpickRuleSettingsMap`.
  Configuration loading checks shape only; rule-set resolution checks IDs and
  values against all known descriptors once, and later stages trust the result.
- Configuration and discovery consider all known descriptors before selection.
  Settings for a known excluded rule are validated. A registered descriptor is
  the schema authority when present; otherwise, configured settings for an ID
  with conflicting discovered callables fail as ambiguous. A conflict with no
  settings stays harmless when the ID is excluded, and selected-rule conflict
  behavior is unchanged.
- Integer values accept the eight signed and unsigned CLR integral types only
  when the value fits in `Int32`. Boolean, null, string, decimal, floating-point,
  and out-of-range values are rejected. Schemas require `Type = 'Integer'` and
  `Default`, permit `Minimum` and `Maximum`, reject other keys, and require the
  default to satisfy its declared bounds.
- A partial-line finding uses the non-empty overlap between the physical line
  content and submitted fragment. If the fragment intersects only a line
  terminator, the finding anchors to an in-fragment code unit of that terminator.
  The complete physical line is still measured. Empty lines never exceed the
  positive minimum; final unterminated lines are checked.
- Raw producers validate their own explicit `Context.RuleSettings` against the
  same schema and defaults, preserving their direct-call output conventions.
  Descriptor execution independently validates before applicability and passes
  separate effective-context copies to predicates and producers.

## Validation gates

Use the repository test runner and run targeted tests on Windows PowerShell
5.1 and PowerShell 7 before broader validation. Do not add a new test runner.

- Configuration/schema tests: empty policy, coexistence with compatibility,
  valid and invalid rule IDs, missing packages, known excluded rules, unknown
  setting names, invalid schema declarations/defaults/ranges and values,
  duplicates, and fail-fast behavior before target reads even without
  `-ErrorAction Stop`.
- Descriptor tests: both declaration surfaces, reconstruction and overrides,
  discovery and registration precedence, direct invocation defaults and
  overrides, per-rule context isolation, predicate/producer separation, and
  candidate reanalysis. Retain identity and package contract suites.
- Line rule tests: threshold boundaries, whitespace, tabs, surrogate pairs,
  LF/CRLF/CR and final lines, comments and multiline strings, file and fragment
  coordinates, fragments spanning partial lines, suppression, no correction,
  standalone output, and default-on selection.
- Correction integration: the 118-plus-three-spaces example in ordinary
  analysis and in correction modes; assert original versus candidate findings
  and existing summary semantics, including no trimming when the whitespace
  correction is unselected or fails. Verify no rule-order dependency.
- Finally run the complete Nitpick suite on both hosts after targeted tests pass.
  Coverage and performance measurements are separate follow-ups unless a
  regression or explicit request warrants them.
