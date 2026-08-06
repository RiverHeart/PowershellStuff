<#
.SYNOPSIS
    Returns changed files matching Git pathspecs.
#>
function Get-GitChangedFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Changeset,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $PathSpec
    )

    return Get-GitChangedPath `
        -Root $Changeset.Root `
        -CompareRef $Changeset.CompareRef `
        -HeadCommit $Changeset.HeadCommit `
        -PathSpec $PathSpec
}
