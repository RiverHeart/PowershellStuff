<#
.SYNOPSIS
    Retrieves a coverage map from a given coverage XML file.

.DESCRIPTION
    This function parses a coverage XML file and returns a hashtable where
    the keys are normalized relative paths to source files and the values
    are hashtables mapping line numbers to coverage status (true if covered, false otherwise).

.EXAMPLE
    Basic usage

    $coverageMap = Get-CoverageMap -CoveragePath "coverage.xml"
#>
function Get-CoverageMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CoveragePath
    )

    if (-not (Test-Path -Path $CoveragePath)) {
        throw "Coverage file not found: $CoveragePath"
    }

    [xml] $report = Get-Content -Path $CoveragePath -Raw
    $map = @{}

    foreach ($package in $report.report.package) {
        $packageName = [string] $package.name

        foreach ($sourceFile in $package.sourcefile) {
            $sourceName = [string] $sourceFile.name
            $relative = if ($sourceName.Contains('/')) {
                $sourceName
            } elseif ([string]::IsNullOrWhiteSpace($packageName)) {
                $sourceName
            } else {
                "$packageName/$sourceName"
            }

            $normalizedRelative = Normalize-RelativePath -Path $relative
            if (-not $map.ContainsKey($normalizedRelative)) {
                $map[$normalizedRelative] = @{}
            }

            foreach ($line in $sourceFile.line) {
                $lineNumber = [int] $line.nr
                $isCovered = ([int] $line.ci -gt 0)
                $map[$normalizedRelative][$lineNumber] = $isCovered
            }
        }
    }

    return $map
}
