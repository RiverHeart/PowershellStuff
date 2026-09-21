> [!WARNING]
> DO NOT, REPEAT, DO NOT enable recursion when using `Ast.Find/FindAll()` methods in a ScriptAnalyzer rule. Sure, your tests may run fine calling your rule directly in tests, BUT, Invoke-ScriptAnalyzer will pass the entire file before recursively passing each individual AST node, which means that if you recurse you're going to parse the entire file yourself to get the thing you want... then you will GET the node you actually wanted and TADA, two damned results per rule with nary a helpful message in sight, despite the fact that this isn't intended behavior. A small miracle I managed to remember this from a previous debugging session, what an awful footgun... (╯‵□′)╯︵┻━┻
> 
> Or something like that. Just be grateful my crap memory recalled this much.


**NOTE:** ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export helper any helper functions from this module that do not use those verbs.

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.

## Why Not Use PSScriptAnalyzer?

Currently, I feel that ScriptAnalyzer is not flexible enough for what I'd like to do.

The inability to limit tests to certain file names is problematic since rule suppression doesn't behave well in Pester where tests may run against purposefully incorrect code. More over, tests shouldn't be limited to files so much as scoped to them. There isn't a compelling reason why the ScriptAnalyzer should be limited to Powershell at this stage in its life. If ScriptAnalyzer runs against a Powershell file and is given a test which exposes a ScriptBlockAst parameter then the calling contract is obviously "get the Powershell AST and pass it to the test" but if given a SQL file why not just run the test and retrieve a DiagnosticRecord? Just because Powershell can't readily obtain an AST of say, SQL, doesn't mean it can't detect SQL issues by other means. The ScriptDom class from the SqlServer module can create SQL ASTs and supports vistors for analysis. Sure, there may be a better tool for the job, but it won't be PowerShell based.

Another low hanging fruit problem is the inability to have ScriptAnalyzer throw an error for a given severity. This means that using it for CI tasks or from task runners (Psake, InvokeBuild, PleaseWork) requires manually parsing the results and throwing an error yourself. Clearly this is a bad developer experience as it's manual, unintuitive, and makes the code noisy. This friction should be easy to eliminate but because ScriptAnalyzer was designed as a C# project, the people most likely to use it are forced to become C# devs to contribute back and with C#, you must compile the entire project to test that change which is another source of friction.
