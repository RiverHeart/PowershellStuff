# Pester under task runners

One observed Nitpick test-runner issue involved Please Work's in-process task execution. The
full suite produced several seemingly unrelated failures when invoked from the default task
scope, while the repository test runner invoked directly passed; running a focused test path
could also pass while the full suite failed. Running the task in Please Work's dedicated
runspace or starting the test runner in a child PowerShell process passed.

This points to session-state interaction between Pester, module imports, and a task runner's
dynamic scope; it is not evidence of a general Pester defect, and the precise trigger may depend
on the tests involved. If Pester failures appear unrelated, especially around command visibility,
module cleanup, or mocks, compare direct test-runner execution with the task-runner invocation
and check both focused and full-suite runs. For Nitpick, the `test` task uses a child process to
keep suite state isolated.
