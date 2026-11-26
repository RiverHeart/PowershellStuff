<#
.SYNOPSIS
    Resolves the appropriate coverage key for a given changed path.

.EXAMPLE
    Basic usage

    $coverageKey = Resolve-CoverageKey `
        -ChangedPath "folder/file.txt" `
        -CoverageKeys @("folder/file.txt", "folder/otherfile.txt")
#>
function Resolve-CoverageKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ChangedPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $CoverageKeys
    )

    $normalizedChanged = Normalize-RelativePath -Path $ChangedPath
    $exact = @($CoverageKeys | Where-Object {
        $_.ToLowerInvariant() -eq $normalizedChanged.ToLowerInvariant()
    })

    if ($exact.Count -eq 1) {
        return $exact[0]
    }

    $suffixMatches = @($CoverageKeys | Where-Object {
            $candidate = $_.ToLowerInvariant()
            $changed = $normalizedChanged.ToLowerInvariant()
            $changed.EndsWith($candidate) -or $candidate.EndsWith($changed)
        })

    if ($suffixMatches.Count -eq 1) {
        return $suffixMatches[0]
    }

    return $null
}
