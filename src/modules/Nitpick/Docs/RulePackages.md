# Manifest-Declared Rule Packages

## Foreword

Plans are not immutable and may be changed with user permission. Unforeseen problems may arise. If you discover that an assumption was incorrect or that the implementation is either too vague or harder to implement than necessary as it was described, you should grill the user until you are both aligned on the solution. It may be worthwhile to have the user create a branch to explore solutions in before commiting to one if one solution is not obviously better than another.

## Status

Phases 0 through 6 are implemented; Phase 7 remains proposed.
Phase 6 still owns WPF migration and the broader documentation cutover. It now also
clarifies module ownership: a supporting rule module declares its owner through
`Linting.OwnerModule`, and the owner must declare that supporting module through
`Linting.RuleModules`. Both acquisition routes use the owner's module name as the rule
namespace; arbitrary namespace overrides remain out of scope.

The package contracts live in [RulePackages.Contracts.Tests.ps1](../Tests/RulePackages.Contracts.Tests.ps1);
execution and display attribution also have focused coverage in
[Identity.Contracts.Tests.ps1](../Tests/Identity.Contracts.Tests.ps1).
All current contracts execute without skipped contexts. Existing interface,
interoperability, and autocorrection tests remain active; these contracts do not replace them.

Nitpick acquires explicit packages through `Module`, combines them with built-in rules
and explicit registrations, and builds an invocation-local rule list. Native rule
selection and attribution use qualified IDs; ambient loaded modules are not rule sources.

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
- Arbitrary namespace overrides for manifest-declared packages; a validated
  `OwnerModule` relationship may identify a supporting module's owner.
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
- **Namespace**: The logical owner of a native rule identity. A standalone package
  uses its own module name; a supporting package uses its validated owner's name.
  A module-less registration uses `Local` by default.
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
Only a validated `OwnerModule` relationship can assign a supporting package to an owner;
callable `Details` cannot override the resulting namespace.

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

Native findings and corrections gain `RuleId` as authoritative execution attribution,
computed from the executing `NitpickRule`'s `Namespace`/`Name`. Findings' `RuleName` and
`RuleSuppressionID`, and corrections' `RuleName`, carry that same coordinator-assigned
local `Name` value as transitional compatibility fields. Do not add a
`RuleSuppressionID` property to corrections. A rule's
own callable body never supplies or overrides execution attribution. Native displays,
grouping, selection, and conflict attribution use the qualified `RuleId`;
`ToDiagnosticRecord()` emits `RuleName` as the local name. There is no separate
producer-supplied identity to validate: a rename of a rule's backing command or
registration changes its finding identity immediately, with no compatibility alias
(see Deferred Decisions).

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
- A supporting rule module identifies its owning module with `Linting.OwnerModule`, a
  literal path relative to the supporting module's manifest. For example:

  ```powershell
  PrivateData = @{
      Linting = @{
          OwnerModule = '../../WPF.psd1'
          Rules = @('Test-AvoidBlockingUI')
      }
  }
  ```

  The owner must reciprocally list the supporting module in `RuleModules`. Resolve and
  validate both declarations before importing; derive the namespace from the resolved
  owner's module name. Directly selecting a supporting module returns its rules under
  that same owner namespace, without importing the owner module's runtime.
- The fields are cumulative, not invocation-level include filters.
- With `Linting` present, only declarations contribute rules. An empty declaration
  contributes none; it does not trigger fallback discovery.
- With no `Linting`, explicitly selecting a standalone module discovers only its
  exported compatible `Test-*` and `Measure-*` commands.
- Do not automatically traverse `NestedModules`. Explicitly declaring a supporting
  module permits its own declarations to be resolved, with cycle detection.
- A top-level rule module without `OwnerModule` owns its own namespace. A module declared
  as a supporting rule module must identify that owner; its implementation module name
  does not independently determine rule identity.
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
- Supporting modules under one owner share its namespace. Different rules with the same
  local name therefore compete for one ID and must fail selection rather than receive
  route-dependent identities.
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

## Phase 1: Qualified Rule Identity (Complete)

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

### Implemented

- `NitpickRule` retains local `Name` and descriptive `Source`, and now exposes
  `Namespace` plus the computed `Namespace/Name` `Id`.
- Scriptblock and module-less command rules default to `Local`; command rules with an
  implementing module default to that module's name. `New-Nitpick -Namespace` supports
  an explicit owner independent of the implementing module.
- A shared identity-segment validator rejects empty or whitespace-only values, path
  separators, and wildcard syntax. Callable `Details` metadata cannot set ownership.
- The legacy invocation and source-discovery behavior remain unchanged; registry and
  selection still use their pre-cutover behavior until Phase 4.

## Phase 2: Explicit Module Resolver (Complete)

### Objective

Resolve names and literal paths predictably without importing modules.

### Work

- Evaluate the former `Resolve-Module` private helper and its callers/tests before
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

### Implemented

- The former `Resolve-Module` (name/version lookup only, no path pinning or ambiguity
  rejection) is replaced by [Resolve-NitpickModuleSource](../Private/Resolve-NitpickModuleSource.ps1),
  which dispatches to [Resolve-NitpickModulePathSource](../Private/Resolve-NitpickModulePathSource.ps1)
  or [Resolve-NitpickModuleNameSource](../Private/Resolve-NitpickModuleNameSource.ps1) based on
  [Test-NitpickModulePathShape](../Private/Test-NitpickModulePathShape.ps1).
- Path-shaped input (a separator, a provider qualifier, a recognized module extension, or an
  existing filesystem entry) is pinned exactly: module directories, `.psd1` manifests, `.psm1`
  script modules, and `.dll` binary modules are accepted; non-FileSystem providers, unsupported
  extensions, and missing paths are rejected without ever falling back to name resolution.
- Bare names reuse a single matching loaded instance, reject multiple loaded instances as
  ambiguous, otherwise select the single highest-version available source and reject equally
  eligible distinct sources at that version. Wildcards are rejected outright.
- [Get-NitpickModuleManifestPath](../Private/Get-NitpickModuleManifestPath.ps1) locates the
  manifest for a resolved entrypoint (itself, or a sibling `<Name>.psd1`) so Phase 3 can read
  declarations without importing code. Version is read via `Import-PowerShellDataFile` and
  `Resolve-Version`, never via module-initializing commands.
- A same-named module loaded from a different path is never reused; an exact-path loaded
  instance is reused as-is. Resolution never calls `Import-Module`.
- [New-NitpickModule](../Private/New-NitpickModule.ps1) is the single construction point for
  the `Nitpick.Module` descriptor; all three resolution branches call it instead of each
  building their own `[pscustomobject]`, so the shape can only drift in one place. `IsLoaded`
  is derived from `LoadedInstance` rather than passed separately.
- Not yet wired into `Find-Nitpick` or `Start-Nitpicking`; the "Phases 2 and 3" and "Phase 3"
  contract contexts remain skipped until manifest acquisition lands.

## Phase 3: Manifest Acquisition and Package Discovery (Complete)

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

### Implemented

- [Get-NitpickModuleLinting](../Private/Get-NitpickModuleLinting.ps1) reads and validates
  `PrivateData.Linting` from a resolved module's manifest without importing it, distinguishing
  an absent `Linting` key (standalone fallback discovery applies) from an empty-but-present one
  (no fallback, zero rules). `Rules`/`RuleModules` entries must be non-empty, non-whitespace
  strings. Phase 6 adds the optional relative `OwnerModule` path for supporting packages.
- A `DirectedAcyclicGraph` class (copied wholesale from PleaseWork's
  `DirectedAcyclicGraph.ps1`, not taken as a module dependency, to keep Nitpick free of
  non-built-in runtime dependencies for a small reusable class) is colocated directly in
  [Nitpick.psm1](../Nitpick.psm1), consistent with Nitpick's other classes.
- [Resolve-NitpickPackageGraph](../Private/Resolve-NitpickPackageGraph.ps1)
  statically resolves the complete `RuleModules` declaration graph into that
  `DirectedAcyclicGraph` before any import happens, keyed by each node's resolved path.
  Absolute `RuleModules` paths, unresolvable entries, and cycles are all rejected before any
  module initializes. Phase 6 also validates reciprocal owner links and derives each node's
  namespace from its declared owner, rejecting owner mismatches before imports.
- [Get-NitpickPackage](../Private/Get-NitpickPackage.ps1) orchestrates acquisition:
  resolves the top-level source, rejects `Local` as a reserved package namespace, validates the
  full graph, then walks it in topological order, importing each node only if its declared
  `Rules`/standalone fallback requires it. A rule-modules-only parent is never imported. Each
  acquired rule is stamped with its resolved owner module's namespace via
  `New-Nitpick -Namespace` (Phase 6 ownership update); declared `Rules` entries that are
  missing or fail `Assert-CallableSignature` raise an explicit manifest-attributed error.
- [Find-Nitpick](../Public/Interface/Find-Nitpick.ps1) now accepts `string` entries (names or
  paths) alongside the legacy `PSModuleInfo[]` entries for `-Module`, routing strings through
  `Get-NitpickPackage`. The legacy ambient/nested-module-traversal path is left untouched;
  full unification is deferred to Phase 4, when `RulePath`/`RuleModule` are removed.
- **State-leak fix**: the isolation idiom `New-Module -ReturnResult { Import-Module -Scope Local
  -PassThru }`, used by both `Get-NitpickPackage` and the pre-existing `Start-Nitpicking
  -RulePath` path, relied on `-ReturnResult` to keep the imported module out of Nitpick's own
  scope. It does not suppress `New-Module`'s own implicit function exports, so the wrapper
  re-exported the imported module's functions as its own. When a same-named module was already
  loaded elsewhere, this shadowed the original module's commands; `Remove-Module` then cleared
  the package's module-table entry without removing the shadowing function, leaving a leaked,
  still-callable command after teardown. Both call sites now explicitly suppress the wrapper's
  exports with `Export-ModuleMember -Function @() -Alias @()`.
- All 35 `RulePackages.Contracts.Tests.ps1` tests for Phases 1-3 pass (12 Phase 4/5 contexts
  remain appropriately skipped); the full Nitpick suite passes on both PowerShell 7 and Windows
  PowerShell 5.1 with no regressions.

## Phase 4: Public Selection and Registry Cutover (Complete)

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

### Implemented

- [Find-Nitpick](../Public/Interface/Find-Nitpick.ps1) is now purely the shared package
  contract: the legacy `PSModuleInfo[]`/nested-module-traversal path and the
  `-IncludeModule`/`-ExcludeModule`/`-Name` parameters are removed entirely. `-Module`
  is a plain `[string[]]` with no default; a bare call acquires only the built-in
  package, multiple entries acquire additively, and one explicit entry replaces the
  built-in default rather than adding to it. `-IncludeDefaults` adds the built-in
  package back alongside explicit `-Module` entries instead of replacing it; it has no
  effect when `-Module` is omitted unless bound explicitly to `$false`, which acquires
  nothing. `-IncludeRule`/`-ExcludeRule` filter the resulting `NitpickRule` descriptors
  by `Id` with wildcard support.
- [Start-Nitpicking](../Public/Interface/Start-Nitpicking.ps1) replaces `RulePath` and
  `RuleModule` with `-Module` (`[string[]]`). Selection now resolves built-ins, each
  requested package, and registered rules into one `Id`-keyed effective set: literal
  `IncludeRule` selectors are validated against the full known-ID set before exclusions
  and editor-mode filtering; same-ID-same-callable candidates are deduplicated (a
  registered rule's metadata wins); same-ID-different-callable candidates terminate
  selection before any target is read. Excluded rules never participate in conflict
  detection. Its own `-ExcludeDefaults` switch keeps the opt-out built-ins-by-default
  contract end users expect, translating to an explicit `Find-Nitpick -IncludeDefaults`
  argument (`$true` unless `-ExcludeDefaults` is set) so the built-in package and any
  requested packages are always acquired together in one call.
- [Register-Nitpick](../Public/Interface/Register-Nitpick.ps1) gained `-Namespace` and
  now keys the registry by `Id`. A piped `NitpickRule` (for example from `Find-Nitpick`)
  can still have its `-Category`/`-Source`/`-EditorEnabled`/`-Name`/`-Namespace`
  overridden explicitly; with no overrides bound it registers the exact same reference
  (preserving prior reference-equality passthrough behavior). `-IncludeRule`/
  `-ExcludeRule` match `Id` with wildcard support. Its own `-Module` discovery relies on
  `Find-Nitpick`'s replace-by-default behavior with no extra guarding, so
  `Register-Nitpick -Module X` and the equivalent `Find-Nitpick -Module X |
  Register-Nitpick` pipeline register the same package-only rule set.
- [Get-Nitpick](../Public/Interface/Get-Nitpick.ps1) gained `-Id` (exact or wildcard,
  case-insensitive, matching PowerShell's default case-insensitive hashtable key
  comparison) alongside the existing non-key `-Name` filter.
  [Unregister-Nitpick](../Public/Interface/Unregister-Nitpick.ps1) replaced `-Name` with
  `-Id` for the same case-insensitive exact/wildcard registry-key removal.
- **PowerShell 5.1-specific fix**: `Select-Object -First 1`, used by the Phase 2 module
  resolvers ([Resolve-NitpickModuleNameSource](../Private/ModuleResolution/Resolve-NitpickModuleNameSource.ps1),
  [Resolve-NitpickModulePathSource](../Private/ModuleResolution/Resolve-NitpickModulePathSource.ps1)),
  leaks a spurious `StopUpstreamCommandsException` into any caller's `-ErrorVariable` on
  Windows PowerShell 5.1 whenever that caller also specifies `-ErrorAction`. Because
  `Start-Nitpicking` always resolves the built-in package by bare name (either alone or
  alongside requested packages), this fired on effectively every `Start-Nitpicking` call
  that also passed `-ErrorAction`/`-ErrorVariable`. Both resolvers now use array indexing
  (`@(...)[0]`) instead of `Select-Object -First 1`, which avoids the internal
  short-circuit mechanism entirely; `Select-Object -Unique` (no `-First`) is unaffected
  and was left as-is.
- `Start-Nitpicking.RulePath.Tests.ps1` is replaced by
  [Start-Nitpicking.Module.Tests.ps1](../Tests/Public/Interface/Start-Nitpicking.Module.Tests.ps1);
  its exhaustive path-shape-validation edge cases (missing paths, loose scripts,
  wildcards, non-filesystem providers) are already owned by
  [Resolve-NitpickModuleSource.Tests.ps1](../Tests/Private/ModuleResolution/Resolve-NitpickModuleSource.Tests.ps1)
  from Phase 2, so only one representative propagation check was kept here.
  `Find-Nitpick.Tests.ps1` is similarly rewritten around the new built-in-by-default and
  explicit-package contract rather than ambient module scanning.
- All existing `Start-Nitpicking`/`Find-Nitpick`/`Register-Nitpick`/`Get-Nitpick`/
  `Unregister-Nitpick` tests migrated their selectors from bare canonical names (for
  example `UseIsNotOperator`) to qualified IDs (`Nitpick/UseIsNotOperator`,
  `Local/<Name>` for scriptblock registrations with no explicit namespace).
- The full Nitpick suite passes on both PowerShell 7 and Windows PowerShell 5.1 with no
  regressions (352 passed / 350 passed respectively, only the 2 Phase 5 contexts
  remaining appropriately skipped).

## Phase 5: Findings, Corrections, and Coordinator-Owned Identity

**Status: Complete**

### Objective

Make qualified identity observable end-to-end, with the coordinator as the sole source of a
rule's `RuleId` and `RuleName` on every native finding and correction, and of
`RuleSuppressionID` on findings. Do not add a suppression property to corrections.
Long term, converge on `RuleId` as the single rule identity (synonymous with rule name),
removing the separate `RuleName`/`RuleSuppressionID` fields in a later explicit cutover.

### Baseline Before Phase 5

The correction lifecycle described in [SimplifyResolveCorrection.md](SimplifyResolveCorrection.md)
is implemented. `Resolve-NitpickCorrection` returns a `Nitpick.CorrectionProposal`;
`Resolve-NitpickTargetCorrection` wraps it in a `Nitpick.CorrectionResult` with separate
`Proposal`, `Application`, and `Report` owners. Phase 5 adds execution attribution to this
contract; it does not restore the old grouped result schema or change application policy.

Before this phase, `NitpickFinding` had `RuleName` and `RuleSuppressionID`;
`NitpickCorrection` had only `RuleName`. Neither had `RuleId`, and
`NitpickRule.Invoke()` returned producer results without stamping identity.

### Work

- Carry executing-rule identity through the existing lifecycle surfaces:
  - `Proposal.OriginalFindings` and `Proposal.CandidateFindings`, including nested corrections.
  - `Proposal.AcceptedCorrections`, `Proposal.SkippedCorrections[].Correction`, and
    `Proposal.Conflicts[].ExistingCorrection`/`IncomingCorrection`.
  - `Application.CommittedCorrections`.
  - `Report.EffectiveFindings` and `Report.FindingsWithCommittedCorrections`, including
    nested corrections, plus ordinary lint findings emitted without `Fix`.
- Stamp findings' `RuleId`, `RuleName`, and `RuleSuppressionID`, and corrections'
  `RuleId` and `RuleName`, from the executing `NitpickRule`'s `Namespace`/`Name`.
  A rule's own callable body never supplies or overrides execution attribution
  (see [CONTEXT.md](../CONTEXT.md): Local Name).
  **Short-term shape, deliberately cheap to reverse**: `New-NitpickFinding`/
  `New-NitpickCorrection` keep their existing signatures unchanged: the finding helper's
  `-RuleName`/`-RuleSuppressionID` are mandatory, while the correction helper's `-RuleName`
  is optional and it has no `-RuleSuppressionID`. These parameters remain meaningful
  for standalone/direct invocation outside Nitpick.
  Establish one coordinator-owned stamping boundary shared by original execution and
  candidate reanalysis. Both call `NitpickRule.Invoke()`; stamping only in
  `Start-Nitpicking` would miss candidate findings. Attribute findings and nested
  corrections before they enter a proposal. Application and reporting must not rewrite
  proposal identity, clone corrections merely to relabel them, or replace object
  associations used to attribute committed corrections to original findings.
  Revisit whether these parameters should be removed from the producer-facing signature
  entirely once the standalone-invocation story is reconsidered.
- Use qualified execution attribution in conflict reasons and skipped-correction verbose
  messages. Keep direct resolver use possible for standalone findings/corrections that
  have not passed through coordinator execution; do not fabricate a package identity
  from producer-supplied text.
- Preserve target-wide `ChangeSetId` semantics. Stamping identity must not prefix or
  rewrite change-set IDs: intentional cross-rule groups must remain atomic.
- Use qualified `RuleId` in `Format-NitpickText`'s existing rightmost column so findings
  sharing a local name from different namespaces remain visually distinguishable.
  Audit default object formatting and `NitpickFinding.ToString()` for the same identity goal.
- Audit native callers that formerly matched `RuleName` or `Name`. The performance
  measurement script is explicitly deferred from this phase.

### Agreed Decisions

- **Correction suppression field:** corrections currently have no suppression property,
  and diagnostic conversion takes suppression identity from the finding. Stamp corrections
  with `RuleId`/`RuleName` only, retaining `RuleSuppressionID` on findings for now.
  Do not add a correction suppression property or a new mandatory producer parameter.
- **Text presentation:** show qualified `RuleId` in the existing rightmost column.
- **Parser findings:** assign `Nitpick/PowerShellParseError` explicitly. Nitpick owns
  these diagnostics even though they are not produced by a `NitpickRule`. This identity
  does not create a discoverable/selectable rule or a registry entry.
- **Standalone invocation:** when `RuleId` is absent, display the producer-supplied
  `RuleName` without qualification. This is a display fallback, not an inferred identity.
  Do not invent `Local/...` or `_/...` IDs; `Local` denotes an actual owning namespace,
  not unknown ownership. Apply the same label policy to standalone conflict and
  skipped-correction diagnostics.
- **Coordinated execution:** always replace producer-supplied attribution with the
  executing descriptor's identity, including for `Local` rules. Do not validate a
  producer's qualifier against its implementing module: the declaring package or
  registration may own a rule implemented elsewhere. Missing attribution after this
  boundary is a defect; standalone display fallback must not conceal it.
- **Standalone explicit-ID API:** defer a producer-facing `RuleId` parameter to the
  later helper-signature migration. Phase 5 neither overloads `RuleName` with a
  qualification contract nor adds conditional module-ownership validation.
- **Long-term identity:** `RuleId` is the rule name and the intended single identity.
  `RuleName` and `RuleSuppressionID` are transitional compatibility fields, not independent
  identities to extend. Their eventual removal requires an explicit migration of helper
  signatures, standalone invocation, diagnostic conversion, and suppression behavior;
  Phase 5 does not perform that breaking cutover.

### Tests

- Two packages emit the same local name and remain distinguishable in native output.
- Producers supplying different local names or suppression IDs cannot override the
  executing rule's identity, including on nested corrections.
- Preview, successful file writes, and candidate reanalysis retain qualified identity
  across the proposal, application, and report surfaces listed above. Leave a finding
  after reanalysis so candidate finding identity is actually exercised.
- Declined, failed, and stale writes retain candidate identity in the proposal while
  effective reporting selects original findings. No committed corrections appear on
  non-write paths; application/reporting never mutate proposal identity.
- Conflict reasons and skipped-correction diagnostics distinguish equal local names
  from different namespaces.
- Parser findings carry and display `Nitpick/PowerShellParseError` without introducing
  a selectable rule or changing selection/registry behavior.
- Standalone/direct helper and resolver use preserves unqualified labels when `RuleId`
  is absent, without fabricating an identity.
- Coordinated module and `Local` rule findings always have descriptor-assigned IDs;
  producer-supplied attribution cannot override them, and display fallback does not
  substitute for these assertions.
- Ungrouped suggestions, coordinated native fixes, and intentional cross-rule groups remain intact.

### Exit Criteria

Native identity is complete across observable surfaces and focused autocorrection regression
tests pass. See [ADR-0001](adr/0001-defer-scriptanalyzer-adapter.md) for why PSScriptAnalyzer
interoperability and suppression-semantics tests are explicitly out of scope for this phase.

### Implemented

- `NitpickFinding` and `NitpickCorrection` now expose `RuleId`. The context-taking
  `NitpickRule.Invoke()` overload stamps native results and nested corrections in place;
  the default overload delegates to it. Original execution and candidate reanalysis share
  that boundary. Explicit non-native outputs remain unchanged.
- Findings receive the descriptor's `Id`, `Name`, and local suppression name;
  corrections receive `Id` and `Name` only. Producer helper signatures remain unchanged.
- Parser findings receive `Nitpick/PowerShellParseError` directly from the invocation
  coordinator, without adding a selectable rule or registry entry.
- Text output, default finding tables, string conversion, conflicts, and verbose skip
  diagnostics prefer qualified attribution. Standalone objects retain their supplied
  labels when no `RuleId` exists; no namespace is inferred.
- Correction associations and target-wide `ChangeSetId` values remain unchanged.
  Application/report selection never relabels proposal facts. Diagnostic-only findings'
  absent corrections are ignored during grouping rather than counted as skipped edits.
- Contract coverage includes two declaring packages with equal local names, producer
  attribution replacement, nonempty candidate findings, preview/WhatIf/in-memory output,
  committed associations, failed/stale/declined writes, conflicts, standalone labels,
  parser ownership, and intentional cross-rule grouping.
- After targeted validation, the full Nitpick suite passes on PowerShell 7.6.8
  (418 passed) and Windows PowerShell 5.1 (416 passed), with zero failures or skips.
  Modified PowerShell files introduce no new PSScriptAnalyzer diagnostics under the
  repository settings; existing diagnostics remain unchanged.
- The performance measurement script and eventual single-`RuleId` helper migration
  remain deferred as agreed.

## Phase 6: WPF Package and Documentation Migration

**Status: Complete**

### Objective

Exercise package composition and reciprocal ownership with a real declaring module, then
document the breaking changes.

### Work

- Correct WPF's `RuleModules` path to the existing
  `SubModules/WPFRules/WPFRules.psd1` manifest.
- Make WPF's linting declaration rule-modules-only; the parent does not export
  `Test-AvoidBlockingUI`. In WPFRules' manifest, add the exact rule declaration and
  `OwnerModule = '../../WPF.psd1'`. Validate the reciprocal declarations and derive
  `WPF/AvoidBlockingUI` from the owner module name, not the acquisition route.
- Reject stale or conflicting owner links before import or target analysis. Directly
  selecting WPFRules must return `WPF/AvoidBlockingUI`, and selecting WPF must return
  the same ID. Multiple supporting modules may share an owner, but duplicate local
  names under that owner must fail selection as competing IDs.
- Audit WPFRules' dependencies separately from parent loading: its manifest currently
  requires WPF assemblies, so parent-free loading is not a promise of platform independence.
- Update Nitpick help, README, examples, related plan links, and directly affected tests.
- Document old-to-new selectors and parameters, local suppression semantics, trusted
  imports, reserved `Local`, and explicit registration under an owning namespace.
- Keep typed dispatch proposed; explain how its future discovery can reuse descriptors.

### Tests

- WPF manifest acquisition yields `WPF/AvoidBlockingUI` without importing WPF's parent
  runtime; direct WPFRules selection yields the same ID.
- Missing, mismatched, and non-reciprocal owner declarations fail before rule execution.
- Two supporting modules that expose different rules with the same local name under WPF
  fail selection as competing `WPF/RuleName` IDs.
- Repeated selection and scriptblock registration examples behave as documented.

### Exit Criteria

WPF is a working example of manifest integration, and documentation clearly distinguishes
implemented behavior from proposed typed dispatch.

### Implemented

- WPF declares WPFRules through the corrected manifest path. WPFRules declares
  `OwnerModule = '../../WPF.psd1'` and its exported rule command.
- Nitpick validates reciprocal ownership before imports and stamps rules with their
  owner's module name, including when the supporting module is acquired directly.
- Contract tests cover stale, mismatched, and non-reciprocal owner references, competing
  local names under one owner, and WPF acquisition through either manifest without
  importing the WPF parent module.
- Nitpick README and public help now describe manifest acquisition, qualified selectors,
  local suppression behavior, trusted imports, the reserved `Local` namespace, and typed
  AST dispatch as proposed.
- Validation: 52 focused package-contract tests pass on PowerShell 7.6.8 and Windows
  PowerShell 5.1; the full Nitpick suite passes on both editions (423/421 tests), and
  the WPF suite passes on PowerShell 7.6.8 (495 tests).

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
- Qualified suppression syntax and a deliberate migration of suppression semantics, including
  any rename-compatibility/legacy-alias mechanism for a rule's Local Name.
- Arbitrary configurable package namespaces, aliases, and installed-package auto-discovery.
  `OwnerModule` establishes ownership from a real module relationship; it is not a free-form
  namespace override.
- Typed AST rule declarations and an external analyzer adapter; see
  [ADR-0001](adr/0001-defer-scriptanalyzer-adapter.md) for why direct PSScriptAnalyzer
  `-CustomRulePath` compatibility is de-emphasized rather than extended alongside Phase 5.
- Rule acquisition caching and reload policy, only after profiling and lifecycle tests.
