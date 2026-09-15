<#
.SYNOPSIS
    Resolves an explicit TaskFile or discovers one in the current directory hierarchy.
#>
function Resolve-TaskFilePath {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Path
    )

    if (-not [string]::IsNullOrEmpty($Path)) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }

    if ($PWD.Provider.Name -ne 'FileSystem') {
        throw 'TaskFile discovery requires a FileSystem location.'
    }

    $Directory = [System.IO.DirectoryInfo]::new($PWD.ProviderPath)
    while ($null -ne $Directory) {
        $Candidate = Join-Path $Directory.FullName 'TaskFile.ps1'
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Candidate).ProviderPath
        }

        $Directory = $Directory.Parent
    }

    throw "Could not find 'TaskFile.ps1' in '$($PWD.ProviderPath)' or any parent directory."
}
