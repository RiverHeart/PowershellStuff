> [!WARNING]
> DO NOT, REPEAT, DO NOT enable recursion when using `Ast.Find/FindAll()` methods in a ScriptAnalyzer rule. Sure, your tests may run fine calling your rule directly in tests, BUT, Invoke-ScriptAnalyzer will pass the entire file before recursively passing each individual AST node, which means that if you recurse you're going to parse the entire file yourself to get the thing you want... then you will GET the node you actually wanted and TADA, two damned results per rule with nary a helpful message in sight, despite the fact that this isn't intended behavior. A small miracle I managed to remember this from a previous debugging session, what an awful footgun... (╯‵□′)╯︵┻━┻
> 
> Or something like that. Just be grateful my crap memory recalled this much.


**NOTE:** ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export helper any helper functions from this module that do not use those verbs.

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.
