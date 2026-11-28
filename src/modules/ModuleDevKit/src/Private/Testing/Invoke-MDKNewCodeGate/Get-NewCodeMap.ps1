using namespace System.Collections.Generic

<#
.SYNOPSIS
    Gets a map of new code lines in the repository compared to the base reference.

.EXAMPLE
    Basic usage

    $newCodeMap = Get-NewCodeMap `
        -RepositoryRoot "C:\path\to\repo" `
        -BaseRef "main" `
        -IncludePattern "*.ps1"
#>
function Get-NewCodeMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RepositoryRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BaseRef,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $IncludePattern
    )

    $diffArgs = @(
        '-C', $RepositoryRoot,
        'diff',
        '--unified=0',
        '--no-color',
        "$BaseRef...HEAD",
        '--'
    ) + $IncludePattern

    $diffOutput = & git @diffArgs 2>$null
    if ($LASTEXITCODE -gt 1) {
        throw "git diff failed for range '$BaseRef...HEAD'."
    }

    $changed = @{}
    $currentFile = $null

    foreach ($line in $diffOutput) {
        if ($line -match '^\+\+\+ b/(.+)$') {
            $currentFile = Normalize-RelativePath -Path $Matches[1]
            if (-not $changed.ContainsKey($currentFile)) {
                $changed[$currentFile] = [HashSet[int]]::new()
            }
            continue
        }

        if ($null -ne $currentFile -and
            $line -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@'
        ) {
            $start = [int] $Matches[1]
            $count = if ([string]::IsNullOrWhiteSpace($Matches[2])) { 1 } else { [int] $Matches[2] }

            if ($count -gt 0) {
                for ($i = 0; $i -lt $count; $i++) {
                    [void] $changed[$currentFile].Add($start + $i)
                }
            }
        }
    }

    return $changed
}
