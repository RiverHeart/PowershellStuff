test: {
    param(
        [string] $Project,
        [string] $TestSuite,
        [string[]] $Path
    )

    Invoke-MDKTest @PSBoundParameters
}

lint: {
    param([switch] $All)

    if ($All) {
        Start-Nitpicking
    } else {
        git diff --name-only --diff-filter=d --relative $TaskFileRoot | Start-Nitpicking
    }
}
