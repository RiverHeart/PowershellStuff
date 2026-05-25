function Set-TaskManagerTotals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double] $TotalCpuPercent,

        [Parameter(Mandatory)]
        [double] $TotalMemoryPercent,

        [Parameter()]
        [double] $UsedPhysicalMemoryMB = 0,

        [Parameter()]
        [double] $TotalVisibleMemoryMB = 1,

        [Parameter()]
        [double] $TotalProcessMemoryMB = 0,

        [Parameter()]
        [ValidateSet('initial', 'refresh')]
        [string] $Phase = 'refresh'
    )

    $window = Reference 'Window'
    $windowState = if ($null -ne $window.DataContext) {
        Write-Debug ("TaskManager $Phase totals update target: Window.DataContext")
        $window.DataContext
    } else {
        Write-Debug ("TaskManager $Phase totals update target: Window.Tag (DataContext unavailable)")
        $window.Tag
    }

    $windowState.TotalCpuPercent = $TotalCpuPercent
    $windowState.TotalMemoryPercent = $TotalMemoryPercent

    Write-Debug (
        "TaskManager $Phase totals set: CPU={0:N1}%, Memory={1:N1}% (Used={2:N1}MB/{3:N1}MB, ProcessSum={4:N1}MB)" -f
        [double] $TotalCpuPercent,
        [double] $TotalMemoryPercent,
        [double] $UsedPhysicalMemoryMB,
        [double] $TotalVisibleMemoryMB,
        [double] $TotalProcessMemoryMB
    )
}
