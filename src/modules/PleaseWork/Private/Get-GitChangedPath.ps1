using namespace System.Collections.Generic

<#
.SYNOPSIS
    Returns committed and working-tree changes matching optional Git pathspecs.
#>
function Get-GitChangedPath {
    [CmdletBinding()]
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
            throw "Git could not read committed changes from '$CompareRef' to '$HeadCommit'."
        }
        & $AddFiles $CommittedFiles
    }

    [string[]] $TrackedFiles = @(git -C $Root diff --name-only $HeadCommit -- @PathSpec)
    if ($LASTEXITCODE -ne 0) {
        throw "Git could not read staged and unstaged changes from '$HeadCommit'."
    }
    & $AddFiles $TrackedFiles

    [string[]] $UntrackedFiles = @(
        git -C $Root ls-files --others --exclude-standard -- @PathSpec
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Git could not read untracked files.'
    }
    & $AddFiles $UntrackedFiles

    return $Files.ToArray()
}
