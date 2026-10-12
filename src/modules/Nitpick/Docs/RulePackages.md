# Manifest-Declared Rule Packages

## Status

Phase 0 is implemented; Phases 1 through 7 remain proposed.
The examples below describe the intended API, not the current API.

The contracts live in [RulePackages.Contracts.Tests.ps1](../Tests/RulePackages.Contracts.Tests.ps1).
Existing invariants execute now. Future contracts are discoverable in skipped contexts
whose names identify the implementing phases. Existing interface, interoperability,
and autocorrection tests remain active; these contracts do not replace them.

Nitpick currently discovers compatible commands across loaded modules and their
loaded nested modules. `Start-Nitpicking` also accepts `RulePath` and `RuleModule`,
combines discovery with explicit registrations, and builds an invocation-local rule
list. Rules are currently keyed and selected by an unqualified canonical name.

This plan replaces ambient discovery with explicit rule sources and qualified
native identities. Breaking changes are acceptable for this experimental project;
the cutover must be deliberate, documented, and covered by tests.

## Goals

- Let a module declare its own rules and dedicated rule modules in its manifest.
- Load dedicated rule modules without unnecessarily importing the parent runtime.
- Make rule selection independent of unrelated modules loaded in the session.
- Support additive packages and package-only execution through the same selectors.
- Distinguish equally named rules from different packages.
- Preserve invocation-local selection and explicit persistent registration.
- Preserve existing PSScriptAnalyzer diagnostic names and suppression compatibility.
- Keep source resolution and declaration traversal out of the execution coordinator.

## Non-Goals

- Typed AST dispatch or a new callable signature; see [Typed AST Rule Dispatch](TypedAstRuleDispatch.md).
- A new PSScriptAnalyzer adapter, mandatory compatibility break, or new correction engine.
- Automatic installation, recursive filesystem searches, wildcard module sources,
  automatic reloads, or guaranteed unloading.
- Configurable namespaces for manifest-declared packages.
- Version-qualified rule IDs, rule aliases, or automatic short-name resolution.
- A security sandbox for imported rule code.

## Guiding Model

Resolve sources, obtain rules, construct identities, select rules, then execute:

1. Include Nitpick's own built-in package explicitly.
2. Resolve each requested module name or literal module path.
3. Read its declarations before importing code where a manifest is available.
4. Load only the modules needed to obtain the declared rules.
5. Combine package rules with explicit registrations without changing the registry.
6. Validate qualified selectors and selected-rule conflicts before reading targets.
7. Run the existing analysis and correction pipeline with that resolved rule list.

`Start-Nitpicking` must not derive its rule sources from every loaded module.
Loaded-module lookup is still useful for resolving an explicitly requested name.

## Language and Identity

- **Rule package**: A module-owned collection of rules, including rules implemented
  by its declared supporting rule modules.
- **Namespace**: The logical owner of a native rule identity. A package uses the
  declaring module's name; a module-less registration uses `Local` by default.
- **Local rule name**: The canonical callable noun, such as `AvoidBlockingUI`,
  without the `Test-` or `Measure-` verb. Scriptblocks supply their own local name.
- **Rule ID**: The qualified native identity, `Namespace/Name`, such as
  `WPF/AvoidBlockingUI`.
- **Implementing module**: The actual module instance containing the callable.
  It need not have the same name as the declaring package.
- **Source**: Descriptive provenance metadata, not the namespace or registry key.

Keep local `Name`, add `Namespace` and `Id`, and retain the callable's implementing
module identity for deduplication and diagnostics. IDs compare case-insensitively.
Names and namespaces must be nonempty single segments, with no separator,
whitespace-only value, or wildcard syntax. Validate them through one shared helper.

`Local` is reserved for explicit rules without an owning package; a package named
`Local` is rejected. Scriptblock registrations default to `Local` rather than inferring
ownership from their execution scope. Command registrations default to their implementing
module's name, or `Local` for non-module commands. Explicit registration may specify
`-Namespace` to group its rules.
Manifest metadata and callable `Details` must not override package ownership.

Native selection, registry keys, findings, correction attribution, and conflict
diagnostics use `Id`. Preserve the local name separately for existing external
diagnostic conversion and suppression matching. Do not recover it by splitting an
arbitrary finding string after the fact.

### Frozen Output Contract

Discovery returns `NitpickRule` descriptors, accepted by explicit registration, with
local `Name`, `Namespace`, computed `Id`, descriptive `Source`, and exact `Callable`.
The callable retains its implementing module instance. Acquisition must also retain
the declaring manifest/source location internally for conflict diagnostics; that
provenance does not require importing the parent runtime.

Native findings and corrections gain `RuleId` as authoritative execution attribution.
Existing `RuleName` remains the explicit local/external name, and `RuleSuppressionID`
keeps its existing meaning. This avoids repurposing a legacy property or guessing an
external name by parsing a qualified string. Native displays, grouping, selection,
and conflict attribution use `RuleId`; `ToDiagnosticRecord()` uses `RuleName`.
Producer-provided identities are validated or attributed by the coordinator, never
allowed to impersonate a different executing descriptor.

## Intended Public API

```powershell
# Built-ins plus explicitly registered rules; no ambient package discovery.
Start-Nitpicking -Path .\Example.ps1

# Add rules from a named package or a literal path.
Start-Nitpicking -Path .\Example.ps1 -Module WPF
Start-Nitpicking -Path .\Example.ps1 -Module .\WPF\WPF.psd1

# Restrict execution to the selected package.
Start-Nitpicking -Path .\Example.ps1 -Module WPF -IncludeRule 'WPF/*'

# Combine selected rules across namespaces.
Start-Nitpicking -Path .\Example.ps1 -Module WPF `
    -IncludeRule 'Nitpick/UseIsNotOperator','WPF/*' `
    -ExcludeRule 'WPF/AvoidBlockingUI'

# Persist a module-less callable with Local/AvoidFoo as its default ID.
Register-Nitpick -Name AvoidFoo -Source Personal `
    -Callable { param ($ScriptBlockAst) }

# Explicit namespaces are available for persistent registrations.
Register-Nitpick -Namespace ProjectChecks -Name AvoidFoo -Source Personal `
    -Callable { param ($ScriptBlockAst) }
```

`-Module` accepts multiple names or literal paths and replaces `RulePath` and
`RuleModule`. It loads sources; `IncludeRule` and `ExcludeRule` filter rules.
`IncludePath` and `ExcludePath` retain their existing analyzed-file semantics.
Qualified selectors are required after cutover; there are no short-name aliases.

`Find-Nitpick` becomes explicit package discovery, sharing resolution with
`Start-Nitpicking`. With no source it discovers only the built-in package, not
ambient modules. Return identity-bearing rule descriptors rather than bare command
wrappers so the declaring namespace is not lost. Discovery does not register rules.
`Register-Nitpick` without a callable uses this same explicit discovery contract.

Registry lookup/removal uses `-Id`; include/exclude rule selectors also match IDs.
`Name` remains a local construction property, not an ambiguous cross-package lookup.

## Manifest Contract

Keep the existing `PrivateData.Linting` integration point:

```powershell
PrivateData = @{
    Linting = @{
        Rules = @('Test-ParentRule')
        RuleModules = @('SubModules\WPFRules\WPFRules.psd1')
    }
}
```

- `Rules` names exact exported rule commands on the declaring module.
- `RuleModules` identifies dedicated rule modules through literal paths relative to
  the declaring manifest. Do not resolve these through the caller's working directory
  or `PSModulePath`. Reject absolute declaration paths and non-filesystem sources.
- The fields are cumulative, not invocation-level include filters.
- With `Linting` present, only declarations contribute rules. An empty declaration
  contributes none; it does not trigger fallback discovery.
- With no `Linting`, explicitly selecting a standalone module discovers only its
  exported compatible `Test-*` and `Measure-*` commands.
- Do not automatically traverse `NestedModules`. Explicitly declaring a supporting
  module permits its own declarations to be resolved, with cycle detection.
- Supporting modules contribute under the top-level declaring package's namespace.
  Directly selecting `WPFRules` instead gives it the `WPFRules` namespace.
- A missing/nonexported/incompatible explicitly named rule is an error, not a silent skip.
  Standalone export discovery may ignore non-rule commands.

An explicit empty manifest declaration is valid discovery output. Execution still
requires at least one eligible rule. Invalid metadata, missing declared modules, and
import failures terminate source acquisition rather than falling back to built-ins.

## Source Resolution and Safety

- A module name must match exactly; names are not wildcard patterns.
- Reuse a single matching already-loaded instance. Reject ambiguous loaded instances
  instead of choosing one arbitrarily.
- Otherwise select the highest installed version through PowerShell's module lookup.
  Reject equally eligible distinct sources; an explicit path resolves that ambiguity.
- Literal filesystem paths pin the source. Accept module manifests, script modules,
  binary modules, and module directories using PowerShell's entrypoint conventions.
  A same-named loaded module at another path must not satisfy an explicit path.
- Recognize path syntax, provider-qualified paths, file extensions, and bare existing
  filesystem entries consistently. Path-shaped input must never fall back to name
  resolution after a missing-path error. Reject unsupported providers and loose scripts.
- Read manifest data without executing the parent module merely to inspect declarations.
  In particular, do not assume manifest-validation commands are side-effect-free.
- Validate the complete statically resolvable declaration graph before importing
  modules. Detect cycles, normalize paths, and deduplicate repeated references.
- Import a parent only when its declared parent commands or standalone fallback need
  it. A rule-modules-only declaration should not initialize that parent runtime.
- For an already-loaded module, use its instance metadata consistently. Declarations
  only available after importing a non-manifest module cannot be validated beforehand;
  validate them immediately before dependent imports and before target analysis.
- Reuse the scoped import approach without forced reloads or global command exports.
  Imports, assemblies, required modules, and other side effects can nevertheless persist.

Only load trusted packages. Selection failure must not modify the registry or target
files, but cannot roll back arbitrary import side effects.

## Composition and Compatibility

- Built-ins, requested packages, and explicit registrations are additive by default.
- `IncludeRule 'WPF/*'` restricts execution without changing source-loading semantics.
- Validate literal include IDs before exclusions and editor filtering. Unmatched
  wildcard includes are allowed when eligible rules remain; unmatched exclusions are allowed.
- Excluded rules do not participate in ID conflicts. Editor filtering follows conflicts.
- Same ID and same callable execute once. An explicit registration preserves its
  metadata when it matches the selected package callable and ID.
- Different callables or competing module versions with one selected ID terminate
  selection. Report both declaring and implementing origins.
- Different namespaces may legitimately contain the same local name. The same callable
  exposed under different IDs represents distinct rules and is not deduplicated by
  callable alone.
- Preserve existing `Source` requirements initially; the new namespace must not silently
  replace descriptive provenance. No automatic registry migration is needed between
  fresh experimental sessions, but do not mix legacy and qualified keys in one registry.
- Native attribution comes from the executing descriptor, not trusted producer text.
  Define and test how legacy finding and correction names map to that descriptor.
- Preserve existing local-name suppression matching and external `DiagnosticRecord`
  names, including `RuleSuppressionID`. Qualified native suppressions are out of scope.
  Consequently an existing local-name suppression may still affect equally named rules
  across namespaces; qualified selection is available when that is undesirable.
- Preserve coordinated correction grouping, applicability, and transactional saves.
  Do not automatically rewrite producer `ChangeSetId` values: intentional cross-rule
  coordination is already supported.

## Phase 0: Freeze the Contracts (Complete)

### Objective

Express the agreed source, identity, and compatibility boundaries before changing APIs.

### Work

- Add focused contract tests following the pattern in [Autocorrection](AutoCorrection.md).
- Cover currently supported behavior with executable assertions and mark future-phase
  contracts as skipped with their owning phase. Do not skip existing regressions.
- Define identity-bearing discovery output and native/external finding identity fields.
- Record exact public parameter changes and manifest validation diagnostics in help drafts.

### Tests

- Additive versus package-only runs, namespace ownership, and reserved `Local`.
- Qualified selectors, same-name different-package rules, and selected-ID conflicts.
- Parent-free dedicated package loading and no ambient nested discovery.
- Existing external names, suppression IDs, and correction transactions remain stable.

### Exit Criteria

Each later phase has a measurable contract and migration surface; runtime behavior has
not changed merely to make future tests pass.

### Implemented Contract

- Executable invariants cover invocation-local discovery, preservation of registered
  metadata, selection failure before target access, local external identities, and
  transactional coordinated correction previews.
- Pending executable scenarios cover identity segments, explicit path pinning,
  declaration ownership, parent-free loading, empty declarations, standalone exports,
  invalid commands, cycles, reserved namespaces, selection, registry cutover, and
  native/external attribution. Each skipped context identifies its owning phase.
- The frozen descriptor and finding/correction field contract above separates native
  IDs from legacy names. Later phases still own implementation and their complete
  edge-case matrices; skipped scenarios must be activated as their dependencies land.

Phase 0 validation: the focused package contracts pass on Windows PowerShell 5.1 and
PowerShell 7 (6 passed, 39 intentionally skipped). The related interface, external
analyzer, and autocorrection regression run passes on both editions (121 passed,
0 failed, the same 39 future contracts skipped). Runtime code is unchanged.

### Public Help Draft for the Cutover

This draft is intentionally not installed as current command help:

| Command / parameter | Intended help |
| --- | --- |
| `Start-Nitpicking -Module` | Names or literal module paths to acquire as additive rule packages. Does not register acquired rules. Replaces `RulePath` and `RuleModule`. |
| `Find-Nitpick -Module` | Explicit package sources; omitted sources mean only the built-in package. Returns identity-bearing rule descriptors, not bare commands. |
| `Register-Nitpick -Module` | Acquire explicit packages and persist their rule descriptors. With no callable or module, registers only built-ins. |
| `New-Nitpick` / `Register-Nitpick -Namespace` | Namespace for explicit rules; scriptblocks default to reserved `Local`. Source remains separate descriptive metadata. |
| `Get-Nitpick` / `Unregister-Nitpick -Id` | Exact case-insensitive qualified registry identity; replaces ambiguous name-based lookup/removal. |
| `IncludeRule` / `ExcludeRule` | Qualified native rule IDs or wildcard patterns, such as `WPF/*`; no inferred short-name aliases. |
| `IncludePath` / `ExcludePath` | Continue filtering analyzed files, not rule modules. |

Manifest validation errors must identify the declaring source, field, and offending
entry. Distinguish malformed metadata, missing module paths, absolute/non-filesystem
declaration paths, declaration cycles, and missing/nonexported/incompatible commands.
Ambiguous named resolution must identify competing origins and recommend an explicit
path. Selected-ID conflicts must identify both declaring and implementing origins.
Do not silently fall back to built-ins on any acquisition error.

## Phase 1: Qualified Rule Identity

### Objective

Introduce one native identity model without changing how sources are obtained yet.

### Work

- Extend `NitpickRule` and `New-Nitpick` with `Namespace` and computed `Id`.
- Centralize segment validation and module-less `Local` defaults.
- Keep `Source`, local `Name`, and callable implementation identity separate.
- Add identity-bearing descriptors that can retain declaring package provenance.
- Prepare registry and consumer migration without partially switching public selectors.

### Tests

- Deterministic IDs, case-insensitive equality, invalid segments, reserved namespace.
- Scriptblock defaults and explicit namespace overrides.
- WPF-owned rules implemented by WPFRules retain the WPF namespace.
- Metadata overrides cannot silently alter package ownership.

### Exit Criteria

All selected rules can carry stable IDs; the legacy invocation still passes until the
coordinated public cutover in Phase 4.

## Phase 2: Explicit Module Resolver

### Objective

Resolve names and literal paths predictably without importing modules.

### Work

- Evaluate [Resolve-Module](../Private/Resolve-Module.ps1) and its callers/tests before
  extending or replacing it. Reuse version helpers where appropriate.
- Its current path detection and name-based loaded lookup do not meet path pinning,
  bare-file, or ambiguity requirements; do not adopt those semantics unchanged.
- Return a small internal source descriptor containing resolved path, module identity,
  loaded instance when present, and manifest location.
- Use targeted PowerShell lookup instead of scanning/importing unrelated rule packages.

### Tests

- One loaded instance, multiple loaded instances, highest available version, equal-version ambiguity.
- Relative/absolute paths, bare filenames/directories, missing paths, same-name different-path modules.
- Manifest/script/binary entrypoints, invalid extensions, wildcard rejection, provider rejection.
- Resolution and metadata inspection do not execute module initialization.

### Exit Criteria

Source identity is pinned and errors are explicit before imports or target reads.

## Phase 3: Manifest Acquisition and Package Discovery

### Objective

Obtain only declared rules and explicit standalone exports under the correct namespace.

### Work

- Read and validate `PrivateData.Linting` and resolve the declaration graph.
- Load supporting modules in isolated scopes using exact resolved sources.
- Resolve exact exported parent commands only when `Rules` requires the parent.
- Replace implicit nested traversal with explicit declaration traversal.
- Materialize validated identity-bearing rule descriptors once per acquisition.

### Tests

- Cumulative parent rules and rule modules; empty declarations; standalone fallback.
- Nested declarations, cycles, repeated paths, malformed metadata, missing or invalid commands.
- A parent that throws on initialization is not executed for rule-modules-only declarations.
- Supporting functions remain callable without leaking global exports.
- Invalid static graph entries prevent earlier imports; dynamic metadata errors precede analysis.

### Exit Criteria

Explicit packages can be acquired independently of the execution command and ambient
rule-module state.

## Phase 4: Public Selection and Registry Cutover

### Objective

Switch the public native API coherently to explicit sources and qualified selectors.

### Work

- Add `Start-Nitpicking -Module` and remove `RulePath`/`RuleModule`.
- Give `Find-Nitpick` and discovery-based registration the shared package contract.
- Update `Register-Nitpick`, `Get-Nitpick`, and `Unregister-Nitpick` to use qualified
  registry keys and exact `-Id` lookup/removal; retain local `-Name` for construction.
- Use qualified IDs for include/exclude filters, completion, errors, and conflict handling.
- Keep explicit registrations additive and preserve matching-callable metadata.
- Remove ambient automatic discovery rather than hiding it behind an undocumented fallback.
- Leave analyzed-file `IncludePath`/`ExcludePath` behavior unchanged.

### Tests

- Built-ins still run with no sources; unrelated loaded rule modules do not.
- Multiple packages, `WPF/*`, mixed qualified includes, exclusions, literal typos,
  unmatched wildcard includes, and no-eligible-rule errors.
- Same ID/callable runs once; distinct implementations fail before target reads/fixes.
- Explicit metadata survives; registry is unchanged by repeated or failed invocations.
- Registry lookup/removal and short-selector rejection follow the new API.

### Exit Criteria

The native source and selection API is consistent across discovery, execution, and
registration. Existing file-target tests pass with only necessary selector migrations.

## Phase 5: Findings, Corrections, and External Compatibility

### Objective

Make qualified identity observable end-to-end without breaking existing external names.

### Work

- Carry executing-rule identity through candidate/final findings, correction metadata,
  conflicts, grouped results, and text/object output.
- Update suppression and external conversion to consume explicit local identity.
- Apply attribution consistently to native findings and imported diagnostics; do not
  silently accept a foreign producer ID as the executing rule's identity.
- Audit default formatting and all callers that formerly matched `RuleName` or `Name`.

### Tests

- Two packages emit the same local name and remain distinguishable in native output.
- Preview, fix, and reanalysis retain the same qualified ID.
- PSScriptAnalyzer receives unchanged local diagnostic names and suppression IDs.
- Existing local suppressions still apply; qualified selectors do not become suppression aliases.
- Ungrouped suggestions, coordinated native fixes, and intentional cross-rule groups remain intact.

### Exit Criteria

Native identity is complete across observable surfaces and focused interoperability
and autocorrection regression tests pass.

## Phase 6: WPF Package and Documentation Migration

### Objective

Exercise the integration with a real declaring module and document the breaking changes.

### Work

- Migrate WPF's declarations to the agreed cumulative contract. The current declaration
  references `SubModules/WPFRules/WPF.psd1`, but the file is named
  `SubModules/WPFRules/WPFRules.psd1`; correct that path as part of this phase.
- Inspect whether `Test-AvoidBlockingUI` is actually exported by the parent. If it is
  available only in WPFRules, declare the supporting module rather than a nonexistent
  parent command.
- Audit WPFRules' dependencies separately from parent loading: its manifest currently
  requires WPF assemblies, so parent-free loading is not a promise of platform independence.
- Update Nitpick help, README, examples, related plan links, and directly affected tests.
- Document old-to-new selectors and parameters, local suppression semantics, trusted
  imports, reserved `Local`, and explicit registration under an owning namespace.
- Keep typed dispatch proposed; explain how its future discovery can reuse descriptors.

### Tests

- WPF manifest acquisition yields `WPF/AvoidBlockingUI` without initializing WPF's parent runtime.
- Direct WPFRules selection yields `WPFRules/AvoidBlockingUI`.
- Repeated selection and scriptblock registration examples behave as documented.

### Exit Criteria

WPF is a working example of manifest integration, and documentation clearly distinguishes
implemented behavior from proposed typed dispatch.

## Phase 7: Final Validation and Cleanup

### Objective

Verify the complete behavior change and remove obsolete discovery paths.

### Work

- Remove transitional legacy-key code, outdated tests, and unused helpers only after
  identifying all callers.
- Run focused changed-file tests first using the repository test runner; rerun failures
  before broad validation.
- Run the Nitpick suite after focused tests pass, then the affected WPF integration tests.
- Validate Windows PowerShell 5.1 and PowerShell 7 source loading and identity behavior;
  keep WPF tests compatible with its existing 5.1 quality gate.
- Run coverage separately only if requested; no new test infrastructure is required.

### Exit Criteria

All planned contracts execute rather than remaining skipped. No ambient rule discovery
or unqualified native selection remains. Imports never masquerade as registry changes,
and selection failures precede analysis and target mutation.

## Implementation Order

Phases 1 through 5 build on the Phase 0 contracts in sequence. Phase 6 requires the
selection and attribution cutover; Phase 7 is the final verification step. Keep commits
reviewable and intermediate public behavior coherent rather than exposing a partially
qualified registry or changing selectors before their consumers are ready.

## Deferred Decisions

- Version-pinned named module specifications beyond explicit paths.
- Qualified suppression syntax and a deliberate migration of suppression semantics.
- Configurable package namespaces, aliases, and installed-package auto-discovery.
- Typed AST rule declarations and an external analyzer adapter.
- Rule acquisition caching and reload policy, only after profiling and lifecycle tests.
