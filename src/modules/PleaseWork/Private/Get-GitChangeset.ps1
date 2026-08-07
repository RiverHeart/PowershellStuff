<#
.SYNOPSIS
    Resolves the Git commits and changed files used by changeset filters.
#>
function Get-GitChangeset {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory,

        [Parameter()]
        [string] $BaseRef,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $HeadRef = 'HEAD'
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error 'Git is required when a task uses changed().' -Category InvalidOperation
        return
    }

    $Root = git -C $WorkingDirectory rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Root)) {
        Write-Error "TaskFile directory '$WorkingDirectory' is not inside a Git worktree." -Category InvalidOperation
        return
    }
    $Root = [string] @($Root)[0]

    if ([string]::IsNullOrWhiteSpace($BaseRef)) {
        $BaseRef = $env:GIT_PREVIOUS_SUCCESSFUL_COMMIT
    }
    if ([string]::IsNullOrWhiteSpace($BaseRef)) {
        $BaseRef = git -C $Root symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            $BaseRef = $null
        } else {
            $BaseRef = [string] @($BaseRef)[0]
        }
    }

    $HeadCommit = git -C $Root rev-parse --verify "$HeadRef`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git head ref '$HeadRef' does not identify a commit." -Category InvalidOperation
        return
    }
    $HeadCommit = [string] @($HeadCommit)[0]

    if ([string]::IsNullOrWhiteSpace($BaseRef)) {
        [string[]] $Files = @(Get-GitChangedPath -Root $Root -HeadCommit $HeadCommit)
        return [pscustomobject] @{
            Provider = 'Git'
            Root = $Root
            BaseRef = $null
            HeadRef = $HeadRef
            CompareRef = $null
            HeadCommit = $HeadCommit
            Files = $Files
            Available = $false
        }
    }

    $BaseCommit = git -C $Root rev-parse --verify "$BaseRef`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git base ref '$BaseRef' does not identify a commit." -Category InvalidOperation
        return
    }
    $BaseCommit = [string] @($BaseCommit)[0]
    $CompareRef = git -C $Root merge-base $BaseCommit $HeadCommit 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CompareRef)) {
        Write-Error "Git could not find a merge base for '$BaseRef' and '$HeadRef'." -Category InvalidOperation
        return
    }
    $CompareRef = [string] @($CompareRef)[0]

    [string[]] $Files = @(
        Get-GitChangedPath -Root $Root -CompareRef $CompareRef -HeadCommit $HeadCommit
    )

    return [pscustomobject] @{
        Provider = 'Git'
        Root = $Root
        BaseRef = $BaseRef
        HeadRef = $HeadRef
        CompareRef = $CompareRef
        HeadCommit = $HeadCommit
        Files = $Files
        Available = $true
    }
}
