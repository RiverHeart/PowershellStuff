# Nitpick

Nitpick is a Powershell based linter that seeks to replace ScriptAnalyzer. It focuses on rule authoring in Powershell and improving the developer experience.

## Example

```powershell
Start-Nitpicking -FixMode Apply -Script {
    param([Parameter(Mandatory=$true)] $MyParam)
}
```

**Output**
```plaintext
<ScriptBlock>
  2:35  Use '[Parameter(Mandatory)]' instead of assigning it $true.
    2 | -         param([Parameter(Mandatory=$true)] $MyParam)
      |                                     ^^^^^^
      | +         param([Parameter(Mandatory)] $MyParam)

  1 correction applied in memory.

1 finding (1 information; 1 corrected, 0 unresolved) across 1 target in 112 ms
```

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

## Why Not Use PSScriptAnalyzer?

ScriptAnalyzer is clearly king when it comes to Powershell linting, and it's unlikely that I can fully replicate all the functionality it offers, however, it doesn't possess the ergonomics I care about. For starters, you can't run it from the VSCode Powershell Extension which means you have to switch to a different terminal anytime you want to run it and you can't run the VSCode debugger against anything that calls it. As I work almost exclusively in Powershell that's unacceptable.

**Other issues:**

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
| **Built-In Ruleset** | 75 Rules | 3 Rules |  |
| **VSCode Integration** | Yes | Working on it | I can't provide tight integration for squigglies but PowershellEditorServices does allow for driving the editor when Nitpick is run with `-FixMode Guided` from the Powershell Extension terminal. |
| **VSCode Debuggable** | No | Yes | ScriptAnalyzer isn't available from the VSCode Powershell Extension |
| **Configuration File** | Yes | No | |
| **Rule Categories** | No | Working on it |  |
| **Rule Scoping** | No | Working on it |  |
| **Nested Module Support** | No | Yes |  |
| **Errors On Failures** | No | Yes | ScriptAnalyzer doesn't throw for failures so Powershell task runners have to call it from a subprocess with `-EnableExit` or sort through the objects and throw itself. |
| **Text Mode** | No | Yes | Text mode returns text instead of objects, formatted like regular linter output. |

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
