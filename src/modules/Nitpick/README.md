> [!WARNING]
> Pass `$false` as the `searchNestedScriptBlocks` argument when using `Ast.Find()` or `Ast.FindAll()` in a ScriptAnalyzer rule. This still traverses the current script block, but it does not enter nested script-block scopes. ScriptAnalyzer may analyze those nested scopes separately, so including them in the outer search can report the same finding more than once.


**NOTE:** ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export helper any helper functions from this module that do not use those verbs.

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.
  - Add a Nitpick (editor only?) that converts fully qualified types to shorthand and adds `using namespace` for it.

## Why Not Use PSScriptAnalyzer?

Currently, I feel that ScriptAnalyzer is not flexible enough for what I'd like to do.

The inability to limit tests to certain file names is problematic since rule suppression doesn't behave well in Pester where tests may run against purposefully incorrect code. More over, tests shouldn't be limited to files so much as scoped to them. There isn't a compelling reason why the ScriptAnalyzer should be limited to Powershell at this stage in its life. If ScriptAnalyzer runs against a Powershell file and is given a test which exposes a ScriptBlockAst parameter then the calling contract is obviously "get the Powershell AST and pass it to the test" but if given a SQL file why not just run the test and retrieve a DiagnosticRecord? Just because Powershell can't readily obtain an AST of say, SQL, doesn't mean it can't detect SQL issues by other means. The ScriptDom class from the SqlServer module can create SQL ASTs and supports vistors for analysis. Sure, there may be a better tool for the job, but it won't be PowerShell based.

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
