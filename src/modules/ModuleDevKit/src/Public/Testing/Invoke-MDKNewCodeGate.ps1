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
    Invoke-MDKNewCodeGate `
        -BaseRef origin/main `
        -CoveragePath src/modules/WPF/Tests/coverage.xml `
        -MinimumCoveragePercent 80
#>
function Invoke-MDKNewCodeGate {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string] $BaseRef = 'origin/main',

        [ValidateNotNullOrEmpty()]
        [string] $CoveragePath = 'coverage.xml',

        [ValidateRange(0, 100)]
        [double] $MinimumCoveragePercent = 80,

        [ValidateNotNullOrEmpty()]
        [string[]] $IncludePattern = @('*.ps1', '*.psm1'),

        [ValidateNotNullOrEmpty()]
        [string[]] $ExcludePathRegex = @(
            '(?i)^\.github\\',
            '(?i)\\tests?\\',
            '(?i)\.tests\.ps1$'
        )
    )

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

        $newCodeByFileRaw = Get-NewCodeMap `
            -RepositoryRoot $repositoryRoot `
            -BaseRef $BaseRef `
            -IncludePattern $IncludePattern
        $newCodeByFile = @{}

        foreach ($candidatePath in $newCodeByFileRaw.Keys) {
            if (-not (Test-IsExcludedPath -Path $candidatePath -ExcludePathRegex $ExcludePathRegex)) {
                $newCodeByFile[$candidatePath] = $newCodeByFileRaw[$candidatePath]
            }
        }

        if ($newCodeByFile.Count -eq 0) {
            Write-Host 'No new lines found after filters. Gate passed.'
            return
        }

        $coverageByFile = Get-CoverageMap -CoveragePath $resolvedCoveragePath
        $coverageKeys = $coverageByFile.Keys

        $totalNew = 0
        $totalMeasurable = 0
        $totalCovered = 0

        foreach ($changedFile in $newCodeByFile.Keys | Sort-Object) {
            $newLineNumbers = $newCodeByFile[$changedFile] | Sort-Object
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
            return
        }

        $overallPercent = [math]::Round(($totalCovered / $totalMeasurable) * 100, 2)
        Write-Host (
            "New-code coverage summary: covered {0}/{1} measurable new lines ({2}%)." -f
            $totalCovered, $totalMeasurable, $overallPercent
        )

        if ($overallPercent -lt $MinimumCoveragePercent) {
            throw (
                "New-code coverage gate failed: {0}% < required {1}%." -f
                $overallPercent, $MinimumCoveragePercent
            )
        }

        Write-Host (
            "New-code coverage gate passed: {0}% >= required {1}%." -f
            $overallPercent, $MinimumCoveragePercent
        )

    } catch {
        throw
    }
}
