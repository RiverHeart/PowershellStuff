# Module Dev Kit

Module Dev Kit contains tooling for building, packaging, and managing Powershell projects.

## Test configuration

A root `pester.json` marked with `"isRoot": true` defines exactly one layout:

- `Projects` lists project names and their `ConfigPath` values.
- `TestSuites` defines named suites for a single project. Each suite has either
  an inline `Run` configuration or a `ConfigPath`.
- `Run` configures all tests for a single project without requiring a suite name.

A project config referenced by `Projects` may use either `Run` or `TestSuites`.
Calling `Invoke-MDKTest` without selectors runs every configured project and suite.
Use `-Project` and optionally `-TestSuite` to narrow the run.
