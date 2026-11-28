# Please Work Design

## Isolated task runspaces

PleaseWork loads TaskFile setup once in a disposable definition runspace. It
captures supported PowerShell data, helper functions, aliases, file-backed
modules, and task source text as a Task Snapshot. Each task in the resolved plan
then receives a fresh runspace built from that snapshot and disposes the runspace
when the task completes.

The model preserves a single TaskFile definition while preventing one task from
observing functions, variables, modules, aliases, preferences, command-table
changes, or native exit status left by another task. Caller-only state is not
copied into task runspaces. Dependencies are order relationships rather than
dataflow: cross-task coordination must use task output, files, environment,
Git, or another explicit external channel.

### Snapshot module manifests

PleaseWork must import a runner module from its manifest path (`.psd1`), not the
root-module path (`.psm1`) exposed by `PSModuleInfo.Path`, when recreating task
session state. A `.psd1` import registers the manifest's module identity and
metadata, including its name and required-module relationships. A `.psm1` import
does not provide that same manifest identity.

This distinction is observable when another module declares PleaseWork in
`RequiredModules`: if the isolated runspace loaded PleaseWork only from its
`.psm1`, PowerShell can report that no valid PleaseWork module exists even when
the module is loaded and its directory is present in `PSModulePath`. The runner
must therefore resolve `<ModuleName>.psd1` under `ModuleBase` for its own module
snapshot. File-backed TaskFile dependencies should likewise preserve the
manifest path whenever one is available.

## Structured output

Objects cross PleaseWork's runspace boundaries in process. Their types and
properties remain usable, but PowerShell type and formatting tables belong to
individual session states. A module loaded only by a task may therefore provide
formatting metadata that is unavailable in the caller's runspace. For example,
`Invoke-ScriptAnalyzer` returns module-defined `DiagnosticRecord` objects with
custom formatting. Their properties remain useful across the boundary, but their
native console presentation may not.

Task authors have two options when presentation must remain stable:

* Render objects to text inside the task runspace, for example with `Out-String`.
* Normalize objects into plain `PSCustomObject` instances containing the properties callers need.

Rendering preserves presentation but sacrifices structured output.
Normalization preserves pipeline composition but requires the task to choose a
stable output contract.
