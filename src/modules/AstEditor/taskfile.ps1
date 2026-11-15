test: {
    & "$GitRoot/tools/Invoke-Test.ps1" -Suite AstEditor
}

lint: {
    param([switch] $All)

    if ($All) {
        Start-Nitpicking
    } else {
        git diff --name-only --diff-filter=d --relative $TaskFileRoot | Start-Nitpicking
    }
}
