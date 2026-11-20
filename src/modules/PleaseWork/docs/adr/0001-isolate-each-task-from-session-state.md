---
Status: accepted
---

# Isolate each task from session-state changes

PleaseWork previously executed module-bound TaskFile scriptblocks in the caller's
session, which allowed arbitrary task imports and command-table changes to interact
with other nested module scopes. The execution model now loads TaskFile setup
once in a disposable definition runspace, capture an explicit snapshot of
PowerShell data, functions, aliases, and file-backed modules, and create a fresh
disposable runspace for every task. This preserves one authoritative TaskFile
definition and structured output while preventing one task from observing another
task's PowerShell session-state mutations.

## Considered Options

- **Caller or module-bound execution:** preserves the current sharing model but
  retains the module and command-table failures demonstrated by the Pester
  reproduction.
- **One runspace for the whole task plan:** is simpler and isolates the caller,
  but still allows one task to leak session state into later tasks.
- **Reload the TaskFile for every task:** provides clean task state without
  snapshot reconstruction, but repeats arbitrary top-level setup and can produce
  external side effects.
- **One definition run and one runspace per task:** requires explicit snapshot
  reconstruction, but gives the desired isolation without repeating TaskFile setup.

## Consequences

TaskFile dependencies define order, not in-memory data flow. Tasks cannot depend
on caller-only functions, aliases, modules, or on state mutated by an earlier
task. Snapshot values must be PowerShell data that can be recreated safely, and
modules without a stable file source fail explicitly. Files, environment
variables, native processes, assemblies, and other process/system effects are not
transactional and remain outside this isolation guarantee.
