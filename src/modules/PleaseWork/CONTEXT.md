# PleaseWork

This context defines the language used by PleaseWork's task declaration and
execution model.

## Language

**TaskFile**:
A PowerShell file that declares tasks using `name: dependencies { body }` syntax.
_Avoid_: Makefile, build script

**TaskFile Setup**:
The TaskFile's one-time definition of values and helper functions used to create
the initial state for task executions.
_Avoid_: Task body, installation phase

**Task Invocation**:
One request to run a selected task and its dependency plan.
_Avoid_: Task, TaskFile load

**Session-State Isolation**:
A task's guarantee that it cannot observe PowerShell session-state changes left
by another task. External process and system effects are not rolled back.
_Avoid_: Task sandbox, complete isolation

**Task Snapshot**:
The PowerShell data values and command definitions captured after TaskFile
setup and recreated in a task execution. It excludes arbitrary state imported
only into the caller.
_Avoid_: Task state, shared scope

**Module Snapshot**:
The file-backed modules imported during TaskFile setup and recreated in every
task execution. A module without a stable source cannot belong to the snapshot.
Manifest modules retain their `.psd1` identity so required-module resolution
continues to work in isolated runspaces.
_Avoid_: Caller module table, dynamic-module handoff

**Dependency**:
A task-ordering relationship that does not carry in-memory task state.
_Avoid_: Dataflow, task input

**Task Output**:
The structured PowerShell objects emitted on a task's success stream.
_Avoid_: Console log, task result
