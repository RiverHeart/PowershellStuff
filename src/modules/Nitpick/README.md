> [!WARNING]
> DO NOT, REPEAT, DO NOT enable recursion when using `Ast.Find/FindAll()` methods in a ScriptAnalyzer rule. Sure, your tests may run fine calling your rule directly in tests, BUT, Invoke-ScriptAnalyzer will pass the entire file before recursively passing each individual AST node, which means that if you recurse you're going to parse the entire file yourself to get the thing you want... then you will GET the node you actually wanted and TADA, two damned results per rule with nary a helpful message in sight, despite the fact that this isn't intended behavior. A small miracle I managed to remember this from a previous debugging session, what an awful footgun... (╯‵□′)╯︵┻━┻
> 
> Or something like that. Just be grateful my crap memory recalled this much.


**NOTE:** ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export helper any helper functions from this module that do not use those verbs.

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.

## Thoughts

Currently, I feel that ScriptAnalyzer is not flexible enough for what I'd like to do.

The inability to limit tests to certain file types is problematic given the lack of support for suppression in Pester files where rule tests run against purposefully bad code. Further than that, there really isn't a reason why ScriptAnalyzer should be limited to Powershell at all. If a rule exposes a ScriptBlockAst parameter then the contract is obviously powershell but if there is no such parameter why not just call the test and retrieve the DiagnosticRecord anyway? Just because Powershell can't readily obtain an AST of say, Python, doesn't mean it can't detect an issue by other means. For Sql, PowerShell can in fact perform basic linting using ScriptDom and sure, there may be a better tool for the job, but that tool might not be something you can use or alter.

Additionally, the inability to trigger a Powershell error for a given severity means that using it from a task runner like Psake, InvokeBuild, or PleaseWork requires manually parsing the results and throwing an error yourself. Clearly this is a bad developer experience as it's noisy and unintuitive. This friction should be easy to solve but the problem is that contributing to ScriptAnalyzer requires you to become a C# dev.
