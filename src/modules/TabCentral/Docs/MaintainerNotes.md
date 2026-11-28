# Pester module isolation

Keep the `TabCentral` module imports in test `BeforeAll` blocks free of
`-Force`. Pester 5 retains container-local references to exported commands.
These are command references bound to a module session state, not generated
proxy functions. Forcing a new module instance from every test file leaves
some containers calling a previous module session state while `InModuleScope
TabCentral` targets the latest instance. The two instances then have
different hook registries, causing 14 tests to fail during a direct Pester
run.

Removing the module from each file's `AfterAll` does not resolve this because
the retained command references still point at the removed module instance.
Import each test file without `-Force` so all containers use one module
instance, and reset mutable hook state in each test's setup.
