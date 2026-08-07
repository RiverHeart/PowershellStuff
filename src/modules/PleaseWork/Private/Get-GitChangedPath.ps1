using namespace System.Collections.Generic

<#
.SYNOPSIS
    Returns committed and working-tree changes matching optional Git pathspecs.

.DESCRIPTION
    Returns committed and working-tree changes matching optional Git pathspecs. If a compare reference is provided, the returned changes include committed changes from the compare reference to the head commit.
    If no compare reference is provided, only working-tree changes are returned.

    The returned paths are relative to the root of the repository.

.EXAMPLE
    Returns all committed and working-tree changes in the 'src' directory of the
    repository at $GitRoot, comparing the 'origin/main' reference to the 'HEAD' commit.

    Get-GitChangedPath -Root $GitRoot -CompareRef 'origin/main' -HeadCommit 'HEAD' -PathSpec './src/*'
#>
function Get-GitChangedPath {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Root,

        [Parameter()]
        [AllowNull()]
        [string] $CompareRef,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $HeadCommit,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $PathSpec = @()
    )

    $Files = [List[string]]::new()
    $Seen = [HashSet[string]]::new([StringComparer]::Ordinal)
    $AddFiles = {
        param ([string[]] $CandidateFiles)

        foreach ($CandidateFile in $CandidateFiles) {
            if ($Seen.Add($CandidateFile)) {
                $Files.Add($CandidateFile)
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($CompareRef)) {
        [string[]] $CommittedFiles = @(
            git -C $Root diff --name-only $CompareRef $HeadCommit -- @PathSpec
        )
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Git could not read committed changes from '$CompareRef' to '$HeadCommit'."
            return
        }
        & $AddFiles $CommittedFiles
    }

    [string[]] $TrackedFiles = @(git -C $Root diff --name-only $HeadCommit -- @PathSpec)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git could not read staged and unstaged changes from '$HeadCommit'."
        return
    }
    & $AddFiles $TrackedFiles

    [string[]] $UntrackedFiles = @(
        git -C $Root ls-files --others --exclude-standard -- @PathSpec
    )
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Git could not read untracked files.'
        return
    }
    & $AddFiles $UntrackedFiles

    return $Files.ToArray()
}
