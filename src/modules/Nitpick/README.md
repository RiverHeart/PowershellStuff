# Nitpick

Nitpick is a Powershell based linter that seeks to replace ScriptAnalyzer (if for no one but myself). It focuses on rule authoring in Powershell and improving the developer experience.

## Table of Contents

* [Examples](#examples)
  * [Analysis](#analysis)
  * [Remediation](#remediation)
* [Why Not Use PSScriptAnalyzer?](#why-not-use-psscriptanalyzer)
* [PSScriptAnalyzer Integration](#psscriptanalyzer-integration)
* [Feature Comparison](#feature-comparison)
* [Dependencies](#dependencies)

## Examples

### Analysis

Analyze a given piece of code for violations.

```powershell
Start-Nitpicking -Script {
    param([Parameter(Mandatory=$true)] $MyParam)

    if (-not ('foo' -is [string])) { Write-Host "Not a string" }

    $Map = @{ one = 1; two = 2; three = 3 }
    foreach ($Key in $Map.Keys) { if ($Key) { $Map.Remove($Key) } }
}
```

**Output**
```
<ScriptBlock>
  2:22  information  Nitpick/AvoidParameterAttributeBool  Avoid assigning Boolean values to Parameter attribute arguments
  4:9   information  Nitpick/UseIsNotOperator  Uses '-not (<expression> -is <type>)' instead of '<expression> -isnot <type>'.
  7:47  warning      Nitpick/AvoidLiveCollectionMutation  This mutation of '$Map' may invalidate thelive foreach enumerator. Enumerate a snapshot (for example, @($Map.Keys)) or defer mutations until after the loop.

3 findings (1 warning, 2 information) across 1 target in 785 ms
```

### Remediation

Apply automatic fixes to a piece of code.

```powershell
Start-Nitpicking -FixMode Apply -Script {
    param([Parameter(Mandatory=$true)] $MyParam)
}
```

**Output**
```plaintext
<ScriptBlock>
  2:31  Use '[Parameter(Mandatory)]' instead of assigning it $true.
    2 | -     param([Parameter(Mandatory=$true)] $MyParam)
      |                                 ^^^^^^
      | +     param([Parameter(Mandatory)] $MyParam)

  1 correction applied in memory.

1 finding (1 information; 1 corrected, 0 unresolved) across 1 target in 488 ms
```

## Why Not Use PSScriptAnalyzer?

Within the PowerShell community, PSScriptAnalyzer (PSSA) has been the linter of choice for many years now. In fact, I use it every time I work in VSCode via the Powershell Extension. PSSA clearly delivers value and can do things that Nitpick cannot now or may ever do. The issue isn't that it lacks value, but I find myself too often frustrated with the default rules and workflow it imposes.

Several rules enforce broad conventions without enough context to distinguish a mistake from a deliberate design. For example, unused parameters can be required by a callback interface, positional arguments can improve readability, and proxy functions can intentionally shadow built-in commands. Other diagnostics struggle with code whose meaning depends on module scope or runtime composition.

When those findings show up, you have to choose between suppressing them, living with them if they can't be suppressed, or disabling a useful rule. Linters aren't perfect, false positives will happen, which is why being able to suppress them is just as important as finding actual problems. Linters are frequently added to CI pipelines but you can't gate on something that produces false positives, so living with them isn't an option.

Attributes weren't designed for the role they play in suppressing rules. They are awkward to place, finicky to use, verbose, don't regularly occur near the code they apply to, and stick out like a sore thumb because they aren't comments so syntax highlighting gives them the same weight as everything else.

Integrating findings into task runners requires additional handling; and although object-oriented output is great for automation, they do not make good use of terminal real estate when rendered into tables. Some limitations matter especially when developing custom rules and working with test files containing intentionally invalid examples.

## PSScriptAnalyzer Integration

Nitpick does not require PSScriptAnalyzer for normal use, tests, or debugging.
The optional `Nitpick.ScriptAnalyzer` module adapts Nitpick's built-in rules to
PSScriptAnalyzer's custom-rule contract:

```powershell
Invoke-ScriptAnalyzer `
    -Path .\Example.ps1 `
    -CustomRulePath .\Nitpick.ScriptAnalyzer.psd1
```

Use the adapter manifest for `-CustomRulePath`; `Nitpick.psd1` is intentionally
not a PSScriptAnalyzer custom-rule source. The adapter preserves single-edit
suggested corrections and omits multi-edit corrections rather than splitting an
atomic Nitpick fix.

## Feature Comparison

Below is a quick overview of the key differences between PSScriptAnalyzer and Nitpick.

| Criterion | PSScriptAnalyzer | Nitpick | Explanation |
| :---      | :------: | :--------: | :--- |
| **Core Language** | C# | PowerShell |  |
| **Built-In Ruleset** | 75 Rules | 13 Rules |  |
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
