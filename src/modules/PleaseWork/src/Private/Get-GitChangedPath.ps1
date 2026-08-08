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

.EXAMPLE
    Returns changes matching a pathspec using the Git references in an existing changeset.

    Get-GitChangedPath -Changeset $Changeset -PathSpec './src/*'
#>
function Get-GitChangedPath {
    [CmdletBinding(DefaultParameterSetName='Query')]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory,ParameterSetName='Query')]
        [ValidateNotNullOrEmpty()]
        [string] $Root,

        [Parameter(ParameterSetName='Query')]
        [AllowNull()]
        [string] $CompareRef,

        [Parameter(Mandatory,ParameterSetName='Query')]
        [ValidateNotNullOrEmpty()]
        [string] $HeadCommit,

        [Parameter(Mandatory,ParameterSetName='Changeset')]
        [ValidateNotNull()]
        [psobject] $Changeset,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $PathSpec = @()
    )

    if ($PSCmdlet.ParameterSetName -eq 'Changeset') {
        $Root = $Changeset.WorkingRoot
        $CompareRef = $Changeset.CompareRef
        $HeadCommit = $Changeset.HeadCommit
    }

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
        git -C $Root ls-files --full-name --others --exclude-standard -- @PathSpec
    )
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Git could not read untracked files.'
        return
    }
    & $AddFiles $UntrackedFiles

    return $Files.ToArray()
}
