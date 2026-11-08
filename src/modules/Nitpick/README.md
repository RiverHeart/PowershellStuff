# Nitpick

Nitpick is a Powershell based linter that seeks to replace ScriptAnalyzer (if for no one but myself). It focuses on rule authoring in Powershell and improving the developer experience.

## Examples

### Analysis

Analyze a given piece of code for violations.

```powershell
Start-Nitpicking -Script {
    param([Parameter(Mandatory=$true)] $MyParam)
}
```

**Output**
```
(fragment, lines 8-10)
C:\path\to\file.ps1
  9:26  information  Avoid assigning Boolean values to Parameter attribute arguments  Nitpick/AvoidParameterAttributeBool

1 finding (1 information) across 1 target in 39 ms
```

The resulting output starts by identifying the lines that were considered. The filepath is followed up by each finding from that file. Those findings are formatted as `N:M severity Description RuleName`. An uninterrupted filepath followed by `N:M` at the start of each line allows VSCode to mark them as hyperlinks to the violation area.

Finally, the number of findings, their severity, the number of files evaluated, and the time taken to do so is listed.

### Remediation

Apply automatic fixes to a piece of code.

```powershell
Start-Nitpicking -FixMode Apply -Script {
    param([Parameter(Mandatory=$true)] $MyParam)
}
```

**Output**
```plaintext
(fragment, lines 8-10)
C:\path\to\file.ps1
  9:35  Use '[Parameter(Mandatory)]' instead of assigning it $true.
     9 | -         param([Parameter(Mandatory=$true)] $MyParam)
       |                                     ^^^^^^
       | +         param([Parameter(Mandatory)] $MyParam)

  1 correction applied in memory.

1 finding (1 information; 1 corrected, 0 unresolved) across 1 target in 510 ms
```

The resulting output starts by identifying the lines that were considered. The filepath is followed up by the correction applied to each finding. Those corrections are formatted as `N:M Description`. An uninterrupted filepath followed by `N:M` at the start of each line allows VSCode to mark them as hyperlinks to the violation area. A diff is presented that highlights the change area. A note is made that the change was made in memory because a scriptblock is not backed by a file even though it appears in one.

Finally, the number of findings, their severity, the number of corrections applied, unresolved (in case there was no safe correction or if there were multiple ones to choose from), the number of files evaluated, and the time taken to do so is listed.

## Whole-target rule suppression

Put a standalone directive in a file's leading comment/whitespace preamble:

```powershell
# nitpick disable-target Nitpick/AvoidParameterAttributeBool -- Intentional fixture.
# nitpick disable-target WPF/*, */AvoidTrailingWhitespace
```

For a directly submitted ScriptBlock, put the directive at the start of its body:

```powershell
Start-Nitpicking -Script {
    # nitpick disable-target Nitpick/AvoidParameterAttributeBool
    param([Parameter(Mandatory=$true)] $Name)
}
```

The target is the complete file or the ScriptBlock submitted through `-Script`,
not an arbitrary lexical scope. A nested ScriptBlock cannot declare whole-target
suppression when its enclosing file or block is being analyzed. If that nested
ScriptBlock is submitted separately, it becomes the target.

Selectors are qualified rule IDs, separated by whitespace or commas, and use the
same case-insensitive wildcard matching as `-ExcludeRule`. Use `*` to disable all
selected rules for that target. Unmatched qualified selectors are allowed; bare
rule names and command names are invalid. An optional whitespace-delimited `--`
introduces a reason.

Suppressed rules do not execute or offer corrections for that target. Other files
are unaffected, and selected-rule totals are unchanged. Fix modes read directives
again from candidate text, so an unsuppressed rule's edit can add or remove a
suppression. Suppression is not protection against edits by other rules.

Only single-line `#` comments are directives. Shebangs, comments, and whitespace
may precede them; any code token ends the preamble. Trailing directives, block
comments, and text inside strings cannot disable rules. In-memory source strings
use the same policy. AST fragments see only their own tokens, not surrounding
comments, and retain snapshot coordinates. Only the submitted ScriptBlock's own
opening `{` is exempt from ending the preamble. Directives must be on their own
line after it, before `param`, attributes, statements, or nested blocks.

Malformed or unsupported directives produce `Nitpick/InvalidSuppressionDirective`
Warning findings and are ignored as a whole. Neither these warnings nor
`Nitpick/PowerShellParseError` findings can be suppressed, even by `*`.
Invocation-level rule selection and validation still apply.

All five directive actions described in
[ADR 0002](Docs/adr/0002-comment-based-rule-suppression.md) are implemented.
PSScriptAnalyzer suppression behavior is unchanged.
The former `disable-file` spelling is unsupported; it is not an alias.

### Line-specific suppression

Use `disable-line` in a standalone or trailing comment, or `disable-next-line`
in a standalone comment:

```powershell
-not ($Value -is [int]) # nitpick disable-line Nitpick/UseIsNotOperator -- Intentional.

# nitpick disable-next-line Nitpick/UseIsNotOperator
-not ($Other -is [int])
```

These actions use the same qualified selectors, wildcards, lists, and optional
reasons as `disable-target`. They may appear after code or inside nested blocks.
Only native findings whose `ViolationExtent.StartLineNumber` matches the physical
line are suppressed. A multiline finding is not suppressed just because another
part of its extent overlaps that line. `disable-next-line` covers exactly the
next physical line, even if it is blank or a comment; it does not seek a statement.

Unlike whole-target suppression, line suppression runs the producer and filters
its attributed findings before reporting, totals, severity thresholds, or automatic
and guided correction selection. All corrections on a suppressed finding are
excluded as complete fixes. Unsuppressed findings remain eligible, even if their
edits cross a suppressed line: suppression is not an edit-protection mechanism.
Candidate analysis reads directives and line positions afresh. For AST fragments,
comments outside the submitted extent cannot suppress findings inside it.
Parser errors and invalid-directive warnings remain unsuppressible.

### Regional suppression

Use standalone `disable` and `enable` comments to change which rules report
findings over a region:

```powershell
# nitpick disable * -- Intentional fixture region.
-not ($First -is [int])

# nitpick enable Nitpick/UseIsNotOperator
-not ($Second -is [int]) # This rule reports again; other rules remain disabled.
```

Each directive takes effect on the next physical line. Rules start enabled, and
the last preceding matching `disable` or `enable` wins for each qualified Rule ID.
This is not a stack: repeated disables need only one matching enable. An unmatched
enable is a no-op; an unclosed disable extends to the end of the target. Selectors
support the same case-insensitive wildcards, lists, and reasons as other actions.

Regions are textual, not lexically scoped: entering or leaving a function or
ScriptBlock does not reset state. A separately submitted fragment starts enabled
and ignores directives outside its extent. Regional suppression uses the finding's
start line, runs producers, and excludes findings and their complete corrections
through the same policy as line suppression. Candidate snapshots recompute state.

`enable` never overrides `disable-target`, invocation-level `-ExcludeRule`, or
line-specific suppression. Parser errors and invalid-directive warnings cannot
be disabled. Trailing regional directives are malformed and warn; use
`disable-line` for trailing comments.

## Guided navigation

`-FixMode Guided` applies Safe corrections like `Apply`, and prompts only when a finding
is undecided: it offers several corrections, or only non-Safe ones. When run in the
PowerShell extension's terminal with `$psEditor` available, the finding's violation range
is selected in the editor before the prompt. The chosen correction is applied as explicit
consent, including Review or Unsafe corrections; a blank answer skips the finding.
Navigation uses one-based Editor Services coordinates directly from finding extents,
including for a nested ScriptBlock or AST passed through `-Script`. All fix modes use
the complete parse-time snapshot's coordinates, but analyze and edit only the submitted
fragment. Script inputs are still applied only in memory; knowing a source file never
enables saving to it. Later disk changes are not tracked and can make navigation stale.
For file-sourced fragments the text header places `(fragment, lines N-M)` on its own
line above the bare path, preserving VS Code's native path and position linking.
Proposal `OriginalText` and `CandidateText` hold complete snapshots;
`OriginalFragmentText` and `CandidateFragmentText` hold the submitted fragment's text.
`Report.EffectiveText` continues to return only that fragment, including when no
correction is needed or validation fails. File targets and standalone strings retain
their existing output shape. Path filters apply to file selection, not explicit
`-Script` targets, even when those targets have source file provenance.

Guided mode requires an interactive host and terminates under `-NonInteractive`. In
`Apply` and `Preview`, undecided findings are counted in the summary with a hint to use
Guided. To make Guided your personal default, add
`$PSDefaultParameterValues['Start-Nitpicking:FixMode'] = 'Guided'` to your profile.

Plain strings have no exact source provenance and do not navigate. Navigation refers
to the original source location; it does not track subsequent editor changes or
launch VS Code from an ordinary PowerShell terminal.

## Source-oriented rules

`NitpickRule` supports both root-`ScriptBlockAst` rules and document-wide rules
typed to receive `AstDocument`. `Start-Nitpicking` creates one document per target
and dispatches it directly to document rules; AST rules continue to receive the
document's selected AST. Correction reanalysis uses a fresh document for the
rendered snapshot. Document rules should not duplicate that target in context.
PSScriptAnalyzer entry points remain separate AST-based adapters.

`AstEditor\Find-AstScriptExtent` searches target text and returns snapshot-coordinate
extents suitable for both findings and detached edits. Use tokens, not enclosing AST
nodes, to distinguish meaningful token content from ordinary whitespace.

`Measure-AvoidTrailingWhitespace` is the native document rule;
`Test-AvoidTrailingWhitespace` is its PSScriptAnalyzer adapter.
`Nitpick/AvoidTrailingWhitespace` reports trailing spaces and tabs, including blank
lines and an unterminated final line, without changing line terminators. It preserves
whitespace inside meaningful tokens, including strings, here-strings, and escaped
spaces/tabs. Expandable strings are conservatively protected in their entirety,
including interpolation. Comment whitespace is eligible for trimming. Candidates
from malformed snapshots are diagnostic-only, with no automatic correction.
Native execution includes nested scopes once; direct calls default to scope-local
analysis for PSScriptAnalyzer compatibility. Explicit fragments never edit outside
their submitted extent, and a fragment endpoint is not assumed to be a physical EOL.

## Why Not Use PSScriptAnalyzer?

ScriptAnalyzer is clearly king when it comes to Powershell linting, and it's unlikely that I can fully replicate all the functionality it offers, however, it has issues with ergonomics (how easy it is to use) and the default ruleset. As the PSScriptAnalyzer.psd1 of this repo can attest, ScriptAnalyzer has quite a few rules which are sometimes useful but often times produce false positives because they don't understand context well and cannot be easily suppressed.

`PSReviewUnusedParameter` has issues with scriptblocks which capture state and reuse it elsewhere; typically closures but the Pester/Psake modules use this pattern a lot. `TypeNotFound` regularly fails when applied to custom Powershell classes which exist outside the current file but which would exist in module scope. Whoever wrote `PSAvoidUsingWriteHost` seems to think that even with PSv5+ that no one should ever use `Write-Host` under any circumstance because older versions had issues. `PSShouldProcess` doesn't acknowledge that downstream cmdlets consume `WhatIfPreference` regardless of whether the function itself calls `ShouldProcess`.

I could go on but hopefully you get the point. By contrast, Nitpick aims for solve problems where Powershell accepts your code but that code isn't doing what you think it is or is going to fail in some preventable way.

**Issues:**

* You can't run it from the VSCode Powershell Extension which means you have to switch to a different terminal anytime you want to run it.
  * It also means you can't use the VSCode debugger with it, which makes authoring custom rules harder than necessary.
* It doesn't allow you to limit a test to certain file types/names.
  * Rule suppression doesn't behave well in Pester so if you're writing PSSA rules and want to test them, which requires purposefully incorrect code, you're going to have issues.
* Doesn't allow throwing an error for findings of a given severity.
  * This makes CI and pre-commit tasks harder than necessary. Powershell task runners (Psake, InvokeBuild, PleaseWork) must manually parse the results and throw an error themselves or execute ScriptAnalyzer in a dedicated Powershell process with `-EnableExitCode` which only works if error records were produced.
* Renders results exclusively as objects instead of standard text output.
  * Powershell objects are great for a lot of things. This is not one of those things.
* Doesn't support rule categories.
* Rule suppression is difficult to use.
  * The suppression attributes are finicky, I can never remember the syntax, and they don't support line or temporary disabling.
* Doesn't support linting non-Powershell files.
  * I have dreams of Nitpick doing more than Powershell but I'm trying not to put the cart before the horse.
* Developers are forced to become C# devs to contribute to it.
  * Which is fine, tons of tools are written in different languages than they serve but if you, like myself, have no interest the C# language or ecosystem then that's a negative.
* The documentation could be better.
* It doesn't ensure rules are unique even when they originate from the same source. That's why if you run `Invoke-ScriptAnalyzer` with `CustomRulePath` set to module already on the path it'll load rules from it twice and produce duplicate results.

## Feature Comparison

Below is a quick overview of the key differences between PSScriptAnalyzer and Nitpick.

| Criterion | PSScriptAnalyzer | Nitpick | Explanation |
| :---      | :------: | :--------: | :--- |
| **Core Language** | C# | PowerShell |  |
| **Built-In Ruleset** | 75 Rules | 10 Rules |  |
| **VSCode Integration** | Yes | Working on it | I can't provide tight integration for squigglies but PowershellEditorServices does allow for driving the editor when Nitpick is run with `-FixMode Guided` from the Powershell Extension terminal. |
| **VSCode Debuggable** | No | Yes | ScriptAnalyzer isn't available from the VSCode Powershell Extension |
| **Configuration File** | Yes | No | |
| **Rule Categories** | No | Working on it |  |
| **Rule Scoping** | No | Working on it |  |
| **Nested Module Support** | No | Yes |  |
| **Errors On Failures** | No | Yes | ScriptAnalyzer doesn't throw for failures so Powershell task runners have to call it from a subprocess with `-EnableExit` or sort through the objects and throw itself. |
| **Text Mode** | No | Yes | Text mode returns text instead of objects, formatted like regular linter output. |

## Built-in correctness rules

Nitpick includes these rules for common PowerShell value-semantics mistakes:

- **EmptyCollectionMemberAccess** reports direct `@($Items.Property)` captures
  on array expressions, explicit array casts, and array-typed parameters in the
  current lexical scope. Empty arrays can contribute a null item rather than
  zero projected items. Prefer `@($Items | ForEach-Object { $_.Property })` when
  per-item projection is intended. Real collection properties (`Count`, `Length`,
  etc.), methods, dynamic member names, transformed output, and unknown receiver
  types are excluded. Local variable assignment inference, lists, and nested
  property-chain type inference are not supported yet. No automatic fix or null
  filtering is offered, and nonempty cardinality is not proven.

- **ArrayShapeLostThroughControlFlow** reports explicit array expressions emitted
  by branches of an `if` assigned directly to a variable. Output enumeration can
  turn an empty array into absent output and a singleton array into a scalar.
  Even `[array] $Items = if (...) { @() }` can leave the destination null.
  This is an intent warning, not proof of incorrect runtime behavior.
  Local assignments, arguments, redirected output, `return`, unary-comma-protected
  arrays, and outer array capture are excluded. Variable/list output and other
  control-flow or function-output boundaries are not analyzed yet.
  No automatic correction is offered.

- **MisleadingBooleanConversion** reports nonempty string literals cast to
  Boolean and string-literal defaults for `[bool]` parameters. PowerShell treats
  every nonempty string, including `'false'`, as `$true`; parse textual Boolean
  values when that is the intended meaning.
- **PossibleNullItemFromIndexedLookup** is an Information-level intent warning
  for all direct `@(indexed lookup)` captures, including `$Items = @($Map['Key'])`
  and parenthesized lookups. If the lookup returns explicit null, the capture
  contains one null item rather than zero items. The indexed type, missing-key
  status, and desired null policy are not inferred. Pipelines, presence guards,
  multiple statements, and transformed or redirected lookup output are excluded.
  Destination/expression `[array]` or `[object]` casts do not exempt the capture:
  typing does not specify whether null items are intended. No automatic fix is
  offered; use native suppression when null capture is intentional.
- **CollectionComparisonUsedAsAPredicate** reports equality comparisons against
  array expressions or explicitly collection-typed parameters when used as
  `if`, `while`, `do`, or `for` conditions. Collection comparisons filter and
  return matching elements; use `-contains` or `-notcontains` for membership
  tests. Variables whose collection type cannot be established are not reported.
- **StringArgToSwitchParameter** reports Boolean-like string literals such as
  `'false'` immediately following a switch parameter when the command's
  parameter metadata is available. The switch is enabled by its presence, and
  the string is a separate argument; use an explicit value such as
  `-Force:$false` to disable it.

### Keeping a destination collection stable

Instead of assigning an `if`'s enumerated output to the destination, initialize
the destination separately and add the emitted items:

```powershell
$Items = [System.Collections.Generic.List[object]]::new()
$(if ($Condition) {
    Get-Something
} else {
    @()
}) | ForEach-Object {
    $Items.Add($_)
}
```

The empty branch invokes no callbacks. Explicit `$null` items still invoke the
callback and are preserved; filter them only when the application's contract
requires it. For a normal array, initialize `$Items = @()` separately and use
`$Items += $_`, noting the repeated allocation/copying cost.

Outer `@(if (...) { ... })` is another option for an array-of-output contract:
it captures zero/one/many items as an array, but does not preserve the identity
or nesting of each emitted collection. Unary comma preserves an array as a
single output object and therefore expresses a different contract.
`-as [array]` does not normalize absent output to an empty array.
A missing hashtable key evaluates to an explicit null item; use `ContainsKey()`
when absence should produce no output instead of treating it as a null value.

For example, preserve a present null value while omitting a missing key:

```powershell
$Items = @(
    if ($Map.ContainsKey('Key')) {
        $Map['Key']
    }
)
```

If null items are intentional, document that policy with suppression:

```powershell
$Items = @($Map['Key']) # nitpick disable-line Nitpick/PossibleNullItemFromIndexedLookup -- Null is a valid item.
```

## Dependencies

Nitpick requires AstEditor to be installed on `PSModulePath`. Its manifest declares
the dependency, and functions with AstEditor type annotations use
`using module AstEditor` for parse-time class visibility. No profile configuration
or sibling installation path is required for installed modules.

For repository development, `tools/Invoke-Test.ps1` temporarily adds `src/modules`
to the test process's `PSModulePath` and restores it afterward.

## Standalone finding identity

Standalone findings require a qualified `RuleId` without inventing a namespace
from the implementing command. Choose the actual owning namespace, including `Local`
when appropriate:

```powershell
$Extent = { $Value = 1 }.Ast.EndBlock.Statements[0].Extent
$Correction = New-NitpickCorrection `
    -RuleId 'Local/AssignmentStyle' `
    -ViolationExtent $Extent `
    -ReplacementText '$Value = 2' `
    -FilePathOrContext '<ScriptBlock>'`
    -Description 'Replace the assignment.'

New-NitpickFinding `
    -RuleId 'Local/AssignmentStyle' `
    -ViolationExtent $Extent `
    -Message 'Prefer the replacement.' `
    -Severity Information `
    -ScriptPath '<ScriptBlock>' `
    -Explanation 'Standalone example.' `
    -Corrections $Correction
```

IDs must contain exactly a namespace and a local name separated by `/`, with neither
segment empty or containing path separators or wildcard syntax. `RuleId` is the sole identity on native findings and corrections. Diagnostic conversion derives PSScriptAnalyzer's local `RuleName` and `RuleSuppressionID` from the current ID.

**Breaking migration:** replace finding `-RuleName`/`-RuleSuppressionID` with a qualified `-RuleId`, and correction `-RuleName` with optional qualified `-RuleId`. Update native property access to `RuleId`. Constructors reject unknown hashtable keys, including the removed legacy identity fields, and the old positional finding constructor has been removed; use the finding helper or a hashtable with `RuleId`. Detached corrections may omit identity until coordinated execution; no namespace is inferred, and conflict diagnostics label such corrections `unattributed`.

A standalone finding does not stamp its corrections; supply their IDs separately as
shown above. During coordinated execution, Nitpick replaces producer-supplied identity
with the executing rule descriptor's identity on both findings and corrections.
Built-in rule producers now supply `Nitpick/...` IDs for standalone native findings
and corrections; WPF's supporting rule supplies `WPF/AvoidBlockingUI`. Their existing
ScriptAnalyzer diagnostic conversion still emits local names and suppression IDs.
External DiagnosticRecord-only scaffolds are not native producers and remain unchanged.

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.
  - Add a Nitpick (editor only?) that converts fully qualified types to shorthand and adds `using namespace` for it.
  - Add Nitpick rules for the zero-element member-access and `ForEach-Object <MemberName>` / `-WhatIf` pitfalls above.
  - Use the `Select-Object -First`/`-Last` + `StopUpstreamCommandsException` defect as a concrete test ground for PowerShell edition/version compatibility support in Nitpick: a rule (or rule category) that flags constructs known to behave differently, or outright break, across supported PowerShell versions/editions.
  - Add Nitpick rule for using `return` in `Begin` and `Process` blocks.
  - Add rule `MisleadingBooleanConversion` - `[bool]'false'` evaluates to `$true`. Flag provable nonempty-string conversions, including `[bool]` parameters with string-literal defaults. Suggest parsing rather than casting when appropriate.
  - Add rule `CollectionComparisonUsedAsAPredicate` - `if ($Values -eq $Expected)` filters a collection, then tests the returned values’ truthiness. Matching `0`, `$false`, or `''` can therefore produce a false condition. Recommend `-contains` when membership is intended—not for every collection comparison.
  - Add rule `ComparisonResultUsedAsAnExistenceTest` - `if ($Values -match $Pattern)` has the same filtering-versus-Boolean distinction. Deserves an explanation separate from an ordinary operator-style suggestion.
  - Add rule `StringArgToSwitchParameter` - `Invoke-Thing -Force 'false'` does not mean `-Force:$false`; the string becomes another argument. Diagnose only when parameter metadata is known.
  - Add rule `SuccessStreamLeakage` - A known value-returning call such as `$ArrayList.Add($Item)` emits its return value from a function. Focus on calls whose return values are conventionally incidental; don’t flag every unassigned expression.
  - Add rule `ArrayMutationDuringEnumeration` - Removing entries from a collection while directly enumerating that same collection. Start with obvious same-variable cases and known collection types; suggest enumerating a snapshot when appropriate.
  - Add rule `InvalidHashtableAssignment` - `$Options += @{ Name = 'new' }` throws when `Name` already exists; it isn’t an overwrite/merge operation. Detect statically provable duplicate keys.
  - Add rule `MisleadingBreakContinueContext` - Inside `ForEach-Object`, these are not substitutes for loop control in a language foreach statement and can affect enclosing execution unexpectedly. Explain the actual enclosing control structure.
  - Add rule `MatchesUsedTwiceWithoutSuccess` - `$Text -match $Pattern; Use-Value $Matches[1]` A failed match does not clear a previous `$Matches` value. Collection-input `-match` also does not populate it like scalar matching does. Should start with obvious local cases, no pretending to prove correctness across arbitrary control flow.
  - Add rule `TryCatchNonTerminatingError` - `try { Get-Item -LiteralPath $Path } catch { recover }` `Get-Item` generally produces nonterminating errors and has no effective terminating-error policy. Awareness of `$ErrorActionPreference` required but code should function if run without a higher scope variable setting it. If catch defines errors we know to be terminating those could be ignored.
  - Add rule `NativeCmdFailuresAreNotErrors` - `try { & git @Arguments } catch { # Assumes a nonzero exit code reaches here }`. This should be edition/version/policy-aware. PSv6+ have `$PSNativeCommandUseErrorActionPreference` so this is important for PSv5 compatibility. Checking `$LASTEXITCODE` only after another native commad has overwritten it may be worth detecting.
  - Add rule `AvoidMyCommandPath` - `$MyInvocation.MyCommand.Path` used as the current script's path inside a function should be avoided and `$PSCommandPath` or `$PSScriptRoot` suggested when the intent is identifiable. Invocation metadata describes different things depending on where it's accessed.
  - Add rule for **Null comparisons:** collection-sensitive $Value -eq $null, with precise explanations.
  - Add rules for **identical comparison operands / duplicate branches:** strong copy-and-paste bug signals.
  - Add rules for **Unreachable statements:** after unconditional return, throw, or applicable loop control.
  - Add rules for **Compatibility:** unsupported syntax, commands, parameters, and types for declared targets.
