test: {
    param([string] $Path)

    if ($Path) {
        & "$GitRoot/tools/Invoke-Test.ps1" -Suite AstEditor -Path $Path
    } else {
        & "$GitRoot/tools/Invoke-Test.ps1" -Suite AstEditor
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

build: {
    Build-MDKModule `
        -ProjectPath $TaskFileRoot `
        -DestinationPath "$TaskFileRoot/artifacts"
}
