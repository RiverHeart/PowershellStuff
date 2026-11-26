test: {
    param([string] $Path)

    if ($Path) {
        & "$GitRoot/tools/Invoke-Test.ps1" -Suite Nitpick -Path $Path
    } else {
        & "$GitRoot/tools/Invoke-Test.ps1" -Suite Nitpick
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
    param([string] $Path)

    & "$GitRoot/tools/Build-PSResource.ps1" -ProjectPath $Path
}

publish: {
    Publish-Module `
        -Path $TaskFileRoot `
        -ApiKey (Read-Host -Prompt 'Enter NuGet API Key')
}
