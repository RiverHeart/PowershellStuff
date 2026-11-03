# Nitpick

Nitpick is a Powershell based linter that seeks to replace ScriptAnalyzer. It focuses on rule authoring in Powershell and improving the developer experience.

## Example

```powershell
Start-Nitpicking -Script {
	param([Parameter(Mandatory=$true)] $MyParam)
} -FixMode Apply
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

## Why Not Use PSScriptAnalyzer?

ScriptAnalyzer is clearly king when it comes to Powershell linting, and it's unlikely that I can fully replicate all the functionality it offers, however, it doesn't possess the ergonomics I care about. For starters, you can't run it from the VSCode Powershell Extension which means you have to switch to a different terminal anytime you want to run it and you can't run the VSCode debugger against anything that calls it. As I work almost exclusively in Powershell that's unacceptable.

**Other issues:**

* The inability to limit a test to certain file types/names is problematic since rule suppression doesn't behave well in Pester where tests may run against purposefully incorrect code.
* The inability to throw an error for a given severity makes CI tasks harder than necessary. Powershell task runners (Psake, InvokeBuild, PleaseWork) must manually parse the results and throw an error themselves or execute ScriptAnalyzer in a dedicated Powershell process with `-EnableExitCode` which only works if error records were produced.
* Renders results exclusively as objects instead of standard text output.
* Doesn't support test categories.
* Rule suppression is difficult to use.
* Doesn't support linting non-Powershell files.
* Developers are forced to become C# devs to contribute to it.
* The documentation isn't great.

## Comparison

Below is a quick overview of the key differences between PSScriptAnalyzer and Nitpick.

| Criterion | PSScriptAnalyzer | Nitpick | Explanation |
| :---      | :------: | :--------: | :--- |
| **Core Language** | C# | PowerShell |  |
| **Built-In Ruleset** | 75 Rules | 3 Rules |  |
| **VSCode Integration** | Yes | No |  |
| **VSCode Debuggable** | No | Yes | ScriptAnalyzer isn't available from the VSCode Powershell Extension |
| **Configuration File** | Yes | No | |
| **Rule Categories** | No | Yes |  |
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
$Correction = New-NitpickCorrection -RuleId 'Local/AssignmentStyle' `
    -ViolationExtent $Extent -ReplacementText '$Value = 2' `
    -FilePathOrContext '<ScriptBlock>' -Description 'Replace the assignment.'
New-NitpickFinding -RuleId 'Local/AssignmentStyle' `
    -ViolationExtent $Extent -Message 'Prefer the replacement.' -Severity Information `
    -ScriptPath '<ScriptBlock>' -Explanation 'Standalone example.' -Corrections $Correction
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
  - Explore VSCode integration via `$PSEditor` (see [EditorTextManipulation.md](./src/modules/AstEditor/Docs/EditorTextManipulation.md)) for violation review/fixes. Nitpick could drive the editor from the terminal by opening the file at the occurence of the offending code and apply the fix before the user, and changes could be reverted before moving on. Sort of like a code review. Application of manual fixes would be nice but not sure how that would work. This could serve as a nice alternative to yet another editor extension. Probably won't be as straight forward as I imagine though.
  - Add Nitpick rules for the zero-element member-access and `ForEach-Object <MemberName>` / `-WhatIf` pitfalls above.
  - Use the `Select-Object -First`/`-Last` + `StopUpstreamCommandsException` defect as a concrete test ground for PowerShell edition/version compatibility support in Nitpick: a rule (or rule category) that flags constructs known to behave differently, or outright break, across supported PowerShell versions/editions.
