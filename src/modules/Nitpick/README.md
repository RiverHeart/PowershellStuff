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
| **Built-In Ruleset** | 75 Rules | 11 Rules |  |
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
