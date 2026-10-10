## Autocorrection

Preview safe corrections and view the diff without modifying files:

```powershell
Start-Nitpicking -Path .\Example.ps1 -Fix -Preview
```

Apply the same validated transaction, or preview using standard PowerShell confirmation semantics:

```powershell
Start-Nitpicking -Path .\Example.ps1 -Fix -Confirm
Start-Nitpicking -Path .\Example.ps1 -Fix -WhatIf
```

`-Fix` now writes file-backed `-Path` targets unless `-Preview`, `-WhatIf`, or a declined
confirmation prevents it. `-Script` inputs always return in-memory output. Use `-Output Object`
for rendered text, candidate/final findings, skipped corrections, conflicts, and write diagnostics.
Only `WasWritten` and `FixedCorrections` indicate committed edits; accepted corrections can
still be previews or rejected at commit. Final severity counts and `-ErrorOn` use candidate
analysis for previews and committed analysis for successful writes. Failed/declined writes
retain the original findings and report no fixed corrections.

Files retain encoding, BOM, and existing newline characters through AstEditor's transactional
save. BOM-less input must be valid UTF-8; BOM-marked UTF-8, UTF-16, and UTF-32 are supported.
Byte fingerprints reject changed sources before replacement. Transactions are per target,
so a failed target does not roll back successful changes to another target. Use
`-ErrorAction Stop` to stop on a reported error.

`UseIsNotOperator` offers a native coordinated fix for `-not (<expression> -is <type>)`:
it removes only `-not` and replaces the actual operator with `-isnot`, retaining parentheses
and trivia. Redirected/background type-test pipelines remain diagnostic-only. ScriptAnalyzer
also receives diagnostics only for this rule. Finding conversion omits corrections with a
`ChangeSetId`, since ScriptAnalyzer cannot enforce atomic groups; ungrouped simple suggestions
remain available.

## Gotchas

### Module-defined output types

Public function files dot-sourced by a script module are parsed separately from classes declared in the root `.psm1`. Referencing one of those classes as a type literal in an `OutputType` attribute, such as `[OutputType([NitpickFinding])]`, can therefore fail with `Unable to find type` while the function file is being parsed.

Use the string overload instead: `[OutputType('NitpickFinding')]`. `OutputTypeAttribute` accepts string type names, and PowerShell exposes each one through command metadata as a `PSTypeName`. The metadata retains the declared name even when its `Type` property cannot be resolved at parse time.

This would be useful to enforce with a Nitpick rule, but an unresolved output type is not enough evidence by itself. It could represent a module-defined class, an optional assembly type, an extended type name, or simply a typo. A reliable rule would need additional evidence, such as locating a matching class declaration in the same module, before recommending the string form.

### Nested script blocks

> [!WARNING]
> Pass `$false` as the `searchNestedScriptBlocks` argument when using `Ast.Find()` or `Ast.FindAll()` in a ScriptAnalyzer rule. This still traverses the current script block, but it does not enter nested script-block scopes. ScriptAnalyzer may analyze those nested scopes separately, so including them in the outer search can report the same finding more than once.

### Duplicate custom rule paths

PSScriptAnalyzer combines custom rule paths from its discovered settings file with paths passed to `-CustomRulePath`. It compares the path strings rather than the modules they resolve to, so a module directory from settings and an explicit path to that module's manifest are treated as separate rule sources. The module is loaded twice and produces duplicate diagnostic records for the same AST and extent.

For example, configuring `./src/modules/Nitpick` in `PSScriptAnalyzerSettings.psd1` while also passing `./src/modules/Nitpick/Nitpick.psd1` to `Invoke-ScriptAnalyzer` duplicates Nitpick findings. Use only one source, or pass `-Settings @{}` when an isolated invocation supplies its own custom rule path.

Nitpick should not emulate this behavior. When Nitpick accepts rules from multiple configuration or command-line sources, it should deduplicate them by resolved module identity, not by the original path strings.

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.
  - Add a Nitpick (editor only?) that converts fully qualified types to shorthand and adds `using namespace` for it.

## Why Not Use PSScriptAnalyzer?

"Stop reinventing the wheel", "contribute to ScriptAnalyzer instead," I hear you cry. Listen, ScriptAnalyzer is clearly functional but neither flexible enough for what I'd like to do nor as ergonomic as other mainstream linters. Contributing to the ScriptAnalyzer project is out of the question as I'm neither a C# dev nor would I be able to convince the powers that be to make sweeping changes just to satisfy my vision.

Moving on to more targeted points, the inability to limit a test to certain file types/names is problematic since rule suppression doesn't behave well in Pester where tests may run against purposefully incorrect code. More over, tests shouldn't be limited to files so much as scoped to them. There isn't a compelling reason why the ScriptAnalyzer should be limited to Powershell at this stage in its life. If ScriptAnalyzer runs against a Powershell file and is given a test which exposes a ScriptBlockAst parameter then the calling contract is obviously "get the Powershell AST and pass it to the test" but if given a SQL file why not just run the test and retrieve a DiagnosticRecord? Just because Powershell can't readily obtain an AST of say, SQL, doesn't mean it can't detect SQL issues by other means. The ScriptDom class from the SqlServer module can create SQL ASTs and supports vistors for analysis. Sure, there may be a better tool for the job, but it won't be PowerShell based.

Another low hanging fruit problem is the inability to have ScriptAnalyzer throw an error for a given severity. This means that using it for CI tasks or from task runners (Psake, InvokeBuild, PleaseWork) requires manually parsing the results and throwing an error yourself. Clearly this is a bad developer experience as it's manual, unintuitive, and makes the code noisy. This friction should be easy to eliminate but because ScriptAnalyzer was designed as a C# project, the people most likely to use it are forced to become C# devs to contribute back and with C#, you must compile the entire project to test that change which is another source of friction.

## Comparison

Below is a quick overview of the key differences between PSScriptAnalyzer and Nitpick.

| Criterion | PSScriptAnalyzer | Nitpick |
| :---      | :------: | :--------: |
| **Core Language** | C# | PowerShell |
| **Built-In Ruleset** | 75 Rules | 2 Rules |
| **VSCode Integration** | Yes | No |
| **VSCode Debuggable** | No | Yes |
| **Configuration File** | Yes | No |
| **Rule Categories** | No | Yes |
| **Rule Scoping** | No | Yes |
| **Nested Module Support** | No | Yes |
| **Errors On Failures** | No | Yes |

## Notes

- ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export any helper functions from this module that do not use those verbs.
- ScriptAnalyzer's `PSUseOutputTypeCorrectly` doesn't take into account strings so `[OutputType('CustomClass')]` fails even though that's the only way it can be expressed due to parse time constraints.
