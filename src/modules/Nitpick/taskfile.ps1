test: {
    param([string] $Path)

    $PowerShellPath = (Get-Process -Id $PID).Path
    $Arguments = @(
        '-NoProfile'
        '-File'
        "$GitRoot/tools/Invoke-Test.ps1"
        '-Suite'
        'Nitpick'
        '-ExitOnError'
    )

    if ($Path) {
        $Arguments += @('-Path', $Path)
    }

    & $PowerShellPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Nitpick tests failed with exit code $LASTEXITCODE."
    }
}

lint: {
    param([switch] $All)

    if ($All) {
        Start-Nitpicking
    } else {
        git diff --name-only --diff-filter=d --relative $TaskFileRoot | Start-Nitpicking
    }
}
