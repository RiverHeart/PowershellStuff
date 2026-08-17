# Please Work Design

## Runspaces

As a task runner, PleaseWork distinguishes itself from similar tools such as `make`, `rake`, and
`just` by being written in PowerShell, a language that deals in structured output (objects) rather
than plain text. Its closest relatives, [psake](https://github.com/psake/psake) and
[Invoke-Build](https://github.com/nightroman/Invoke-Build), establish their own PowerShell scopes
but execute in the caller's runspace. PleaseWork currently offers an opt-in `-Runspace` prototype
that instead executes tasks in a dedicated runspace. Whether this becomes the primary execution
mode remains a design decision.

The combination of runspaces and structured output presents a unique challenge for task output.
Traditional task runners generally forward plain text; a command can emit JSON when a caller needs
structured data. Tools that execute in the caller's runspace can rely on modules loaded there to
provide both their types and PowerShell formatting data.

Objects can cross PleaseWork's in-process runspace boundary, but PowerShell type and formatting
tables belong to individual session states. A module loaded only by a task may therefore provide
formatting metadata that is unavailable in the caller's runspace. For example,
`Invoke-ScriptAnalyzer` returns module-defined `DiagnosticRecord` objects with custom formatting.
Their properties remain useful across the boundary, but their native console presentation may not.

Task authors have two options when presentation must remain stable:

* Render objects to text inside the task runspace, for example with `Out-String`.
* Normalize objects into plain `PSCustomObject` instances containing the properties callers need.

Rendering preserves presentation but sacrifices structured output. Normalization preserves
pipeline composition but requires the task to choose a stable output contract.
