test: {
    & "$(git rev-parse --show-toplevel)/tools/Invoke-Test.ps1" -Suite AstEditor
}
