<#
.SYNOPSIS
    Tests whether Git ignore rules match a path.

.PARAMETER Path
    Path to test.

.PARAMETER GitRepositoryRoot
    Root of the Git worktree containing the path.

.PARAMETER GitExecutable
    Path to the Git executable.

.EXAMPLE
    Basic usage

    Test-GitIgnoredPath `
        -Path ./build/output.txt `
        -GitRepositoryRoot $PWD `
        -GitExecutable (Get-Command git).Source
#>
function Test-GitIgnoredPath {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $GitRepositoryRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $GitExecutable
    )

    $OriginalExitCode = $global:LASTEXITCODE
    try {
        & $GitExecutable -C $GitRepositoryRoot check-ignore --quiet --no-index -- $Path
        $GitExitCode = $LASTEXITCODE
        switch ($GitExitCode) {
            0 { Write-Output -InputObject $true }
            1 { Write-Output -InputObject $false }
            default {
                throw "Git could not evaluate ignore rules for '$Path' (exit code $GitExitCode)."
            }
        }
    } finally {
        $global:LASTEXITCODE = $OriginalExitCode
    }
}
