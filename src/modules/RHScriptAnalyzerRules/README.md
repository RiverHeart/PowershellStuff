NOTE: ScriptAnalyzer primarily searches for functions named `Measure-*` and `Test-*` so we should be safe to export helper functions that do not start with those verbs.

Honestly, ScriptAnalyzer is too painful to be worth using. You'd be better off with grep. At least you'd know why it works or doesn't.
