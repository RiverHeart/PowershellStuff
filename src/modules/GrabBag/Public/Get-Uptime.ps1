<#
.SYNOPSIS
    Returns system uptime. Human readable by default.

.EXAMPLE
    Basic usage, human readable.

    Get-Uptime

.EXAMPLE
    Get the timespan object.

    Get-Uptime -OutputAs Timespan
#>
function Get-Uptime {
    [CmdletBinding()]
    [Alias('uptime')]
    param(
        [ValidateSet('String', 'Timespan')]
        [switch] $OutputAs = 'String'
    )

    $Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    if ($OutputAs -eq 'String') {
        return $Uptime | Format-TimeAsHumanString
    }
    return $Uptime
}
