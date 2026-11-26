<#
.SYNOPSIS
    Finds the Git worktree containing a path.

.PARAMETER Path
    Path beneath the repository to inspect.

.PARAMETER GitExecutable
    Path to the Git executable.

.EXAMPLE
    Get-GitRepositoryRoot -Path $PWD -GitExecutable (Get-Command git).Source
#>
function Get-GitRepositoryRoot {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $GitExecutable
    )

    $RepositoryRoot = & $GitExecutable -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    Write-Output -InputObject (
        [System.IO.Path]::GetFullPath(([string] $RepositoryRoot).Trim())
    ) -NoEnumerate
}
