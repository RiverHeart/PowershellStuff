# Pretty Please

A small, sequential PowerShell task runner with makefile-like task declarations.

```powershell
. ./DirectedAcyclicGraph.ps1

please              # Runs the first declared task in ./TaskFile.ps1
please start
please build
please test -TaskFile ./AnotherTaskFile.ps1
```

A TaskFile declares tasks as `name: dependencies { body }`. Dependencies are optional:

```powershell
lint: {
    Invoke-ScriptAnalyzer -Path ./src
}

test: lint {
    Invoke-Pester
}

build: test {
    dotnet build
}
```

Only the requested task and its transitive dependencies run. Dependencies execute sequentially,
before their dependents, and shared dependencies run once. The runner stops on terminating errors.
Native process exit codes are not converted into errors; the final native command's exit code remains
available through `$LASTEXITCODE`.
