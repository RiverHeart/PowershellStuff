function New-ImageViewerFigureDrawSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 600)]
        [int] $TotalMinutes,

        [Parameter(Mandatory)]
        [ValidateRange(1, 100000)]
        [int] $ImageCount
    )

    $totalSeconds = [double] ($TotalMinutes * 60)
    $phaseDefinitions = @(
        @{ Name = 'Short'; DurationSeconds = 30.0; Ratio = 0.25 }
        @{ Name = 'Medium'; DurationSeconds = 120.0; Ratio = 0.45 }
        @{ Name = 'Long'; DurationSeconds = 300.0; Ratio = 0.30 }
    )

    $durations = [System.Collections.Generic.List[double]]::new()
    $phaseCounts = [ordered] @{}
    $usedSeconds = 0.0

    foreach ($phase in $phaseDefinitions) {
        $durationSeconds = [double] $phase.DurationSeconds
        $budgetSeconds = $totalSeconds * [double] $phase.Ratio
        $count = [int] [Math]::Floor($budgetSeconds / $durationSeconds)

        $phaseCounts[$phase.Name] = $count

        for ($index = 0; $index -lt $count; $index++) {
            $durations.Add($durationSeconds)
            $usedSeconds += $durationSeconds
        }
    }

    $shortestDuration = 30.0
    $remainderSeconds = $totalSeconds - $usedSeconds

    while ($remainderSeconds -ge $shortestDuration) {
        $durations.Add($shortestDuration)
        $phaseCounts.Short = [int] $phaseCounts.Short + 1
        $usedSeconds += $shortestDuration
        $remainderSeconds -= $shortestDuration
    }

    if ($durations.Count -eq 0) {
        $durations.Add([Math]::Max(1.0, $totalSeconds))
        $phaseCounts.Short = [int] $phaseCounts.Short + 1
        $usedSeconds = [double] $durations[0]
        $remainderSeconds = 0.0
    }

    $limiter = 'Time'
    if ($durations.Count -gt $ImageCount) {
        $trimmedDurations = [System.Collections.Generic.List[double]]::new()
        for ($index = 0; $index -lt $ImageCount; $index++) {
            $trimmedDurations.Add([double] $durations[$index])
        }

        $durations = $trimmedDurations
        $limiter = 'Images'
    }

    $plannedSeconds = 0.0
    foreach ($duration in $durations) {
        $plannedSeconds += [double] $duration
    }

    if ($limiter -eq 'Time' -and $durations.Count -gt 0 -and $plannedSeconds -lt $totalSeconds) {
        $lastIndex = $durations.Count - 1
        $durations[$lastIndex] = [double] $durations[$lastIndex] + ($totalSeconds - $plannedSeconds)
        $plannedSeconds = $totalSeconds
    }

    $remainingSeconds = [Math]::Max(0.0, $totalSeconds - $plannedSeconds)

    [pscustomobject] @{
        TotalMinutes      = $TotalMinutes
        TotalSeconds      = $totalSeconds
        PlannedSeconds    = $plannedSeconds
        RemainingSeconds  = $remainingSeconds
        Limiter           = $limiter
        PoseCount         = $durations.Count
        PhaseCounts       = [pscustomobject] $phaseCounts
        DurationsSeconds  = [double[]] $durations.ToArray()
    }
}