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
