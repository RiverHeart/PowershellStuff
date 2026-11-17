
- `PSReviewUnusedParameter` has issues with scriptblocks which capture state and reuse it elsewhere; typically closures but the Pester/Psake modules use this pattern a lot.
- `TypeNotFound` regularly fails when applied to custom Powershell classes which exist outside the current file but which would exist in module scope. Whoever wrote
- `PSAvoidUsingWriteHost` seems to think that even with PSv5+ that no one should ever use - `Write-Host` under any circumstance because older versions had issues.
- `PSShouldProcess` doesn't acknowledge that downstream cmdlets consume `WhatIfPreference` regardless of whether the function itself calls `ShouldProcess`.


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
