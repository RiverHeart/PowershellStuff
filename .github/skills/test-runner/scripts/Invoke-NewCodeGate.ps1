<#
.SYNOPSIS
    Evaluates coverage for newly added PowerShell lines only.

.DESCRIPTION
    Compares changed lines from git diff to JaCoCo coverage output (for example from
    Invoke-Test.ps1 -CoverageMode Full) and fails when new-code coverage is below a threshold.

    This script is a concept-proof and is intentionally separate from Invoke-Test.ps1.

.PARAMETER BaseRef
    Git reference used as baseline for new-code detection.

.PARAMETER CoveragePath
    Path to JaCoCo XML coverage report.

.PARAMETER MinimumCoveragePercent
    Required coverage percentage for measurable new lines.

.PARAMETER IncludePattern
    Git pathspec patterns to scope new-code detection.

.PARAMETER ExcludePathRegex
    Case-insensitive regex patterns used to ignore changed files (for example tests).

.EXAMPLE
    ./.github/skills/test-runner/scripts/Invoke-NewCodeGate.ps1 -BaseRef origin/main -CoveragePath src/modules/WPF/Tests/coverage.xml -MinimumCoveragePercent 80
#>
[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string] $BaseRef = 'origin/main',

    [ValidateNotNullOrEmpty()]
    [string] $CoveragePath = 'coverage.xml',

    [ValidateRange(0, 100)]
    [double] $MinimumCoveragePercent = 80,

    [ValidateNotNullOrEmpty()]
    [string[]] $IncludePattern = @('*.ps1', '*.psm1')

    ,

    [ValidateNotNullOrEmpty()]
    [string[]] $ExcludePathRegex = @(
        '(?i)^\.github\\',
        '(?i)\\tests?\\',
        '(?i)\.tests\.ps1$'
    )
)

function Get-RepositoryRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $StartPath
    )

    $resolvedStart = Resolve-Path -Path $StartPath -ErrorAction SilentlyContinue
    if ($null -eq $resolvedStart) {
        return $null
    }

    $current = $resolvedStart.Path
    while ($current -ne [System.IO.Path]::GetPathRoot($current)) {
        if (Test-Path -Path (Join-Path -Path $current -ChildPath '.git')) {
            return $current
        }

        $parent = Split-Path -Path $current -Parent
        if ($parent -eq $current) {
            break
        }

        $current = $parent
    }

    return $null
}

function Normalize-RelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    return ($Path -replace '^\./', '') -replace '/', '\\'
}

function Resolve-CoverageKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ChangedPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $CoverageKeys
    )

    $normalizedChanged = Normalize-RelativePath -Path $ChangedPath
    $exact = @($CoverageKeys | Where-Object { $_.ToLowerInvariant() -eq $normalizedChanged.ToLowerInvariant() })
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

function Get-NewCodeMap {
    [CmdletBinding()]
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

    foreach ($line in @($diffOutput)) {
        if ($line -match '^\+\+\+ b/(.+)$') {
            $currentFile = Normalize-RelativePath -Path $Matches[1]
            if (-not $changed.ContainsKey($currentFile)) {
                $changed[$currentFile] = [System.Collections.Generic.HashSet[int]]::new()
            }
            continue
        }

        if ($null -ne $currentFile -and $line -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@') {
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

function Test-IsExcludedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ExcludePathRegex
    )

    foreach ($pattern in $ExcludePathRegex) {
        if ($Path -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-CoverageMap {
    [CmdletBinding()]
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

    foreach ($package in @($report.report.package)) {
        $packageName = [string] $package.name
        foreach ($sourceFile in @($package.sourcefile)) {
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

            foreach ($line in @($sourceFile.line)) {
                $lineNumber = [int] $line.nr
                $isCovered = ([int] $line.ci -gt 0)
                $map[$normalizedRelative][$lineNumber] = $isCovered
            }
        }
    }

    return $map
}

try {
    $repositoryRoot = Get-RepositoryRoot -StartPath (Get-Location).Path
    if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
        throw 'Could not locate repository root (.git).'
    }

    $resolvedCoveragePath = if ([System.IO.Path]::IsPathRooted($CoveragePath)) {
        $CoveragePath
    } else {
        Join-Path -Path $repositoryRoot -ChildPath $CoveragePath
    }

    & git -C $repositoryRoot rev-parse --verify $BaseRef 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Baseline ref '$BaseRef' could not be resolved."
    }

    $newCodeByFileRaw = Get-NewCodeMap -RepositoryRoot $repositoryRoot -BaseRef $BaseRef -IncludePattern $IncludePattern
    $newCodeByFile = @{}

    foreach ($candidatePath in $newCodeByFileRaw.Keys) {
        if (-not (Test-IsExcludedPath -Path $candidatePath -ExcludePathRegex $ExcludePathRegex)) {
            $newCodeByFile[$candidatePath] = $newCodeByFileRaw[$candidatePath]
        }
    }

    if ($newCodeByFile.Count -eq 0) {
        Write-Host 'No new lines found after filters. Gate passed.'
        exit 0
    }

    $coverageByFile = Get-CoverageMap -CoveragePath $resolvedCoveragePath
    $coverageKeys = @($coverageByFile.Keys)

    $totalNew = 0
    $totalMeasurable = 0
    $totalCovered = 0

    foreach ($changedFile in @($newCodeByFile.Keys | Sort-Object)) {
        $newLineNumbers = @($newCodeByFile[$changedFile] | Sort-Object)
        $totalNew += $newLineNumbers.Count

        $coverageKey = Resolve-CoverageKey -ChangedPath $changedFile -CoverageKeys $coverageKeys
        if ($null -eq $coverageKey) {
            Write-Host ("[?] {0} -> no matching coverage entry" -f $changedFile)
            continue
        }

        $fileMeasured = 0
        $fileCovered = 0
        foreach ($lineNumber in $newLineNumbers) {
            if ($coverageByFile[$coverageKey].ContainsKey($lineNumber)) {
                $fileMeasured++
                if ($coverageByFile[$coverageKey][$lineNumber]) {
                    $fileCovered++
                }
            }
        }

        $totalMeasurable += $fileMeasured
        $totalCovered += $fileCovered

        if ($fileMeasured -eq 0) {
            Write-Host ("[~] {0} -> measurable 0/{1}" -f $changedFile, $newLineNumbers.Count)
            continue
        }

        $filePercent = [math]::Round(($fileCovered / $fileMeasured) * 100, 2)
        Write-Host ("[*] {0} -> covered {1}/{2} ({3}%)" -f $changedFile, $fileCovered, $fileMeasured, $filePercent)
    }

    if ($totalMeasurable -eq 0) {
        Write-Warning 'No measurable new lines were found in coverage report. Gate passed by default.'
        exit 0
    }

    $overallPercent = [math]::Round(($totalCovered / $totalMeasurable) * 100, 2)
    Write-Host ("New-code coverage summary: covered {0}/{1} measurable new lines ({2}%)." -f $totalCovered, $totalMeasurable, $overallPercent)

    if ($overallPercent -lt $MinimumCoveragePercent) {
        Write-Error ("New-code coverage gate failed: {0}% < required {1}%." -f $overallPercent, $MinimumCoveragePercent)
        exit 1
    }

    Write-Host ("New-code coverage gate passed: {0}% >= required {1}%." -f $overallPercent, $MinimumCoveragePercent)
    exit 0
} catch {
    Write-Error $_
    exit 2
}
