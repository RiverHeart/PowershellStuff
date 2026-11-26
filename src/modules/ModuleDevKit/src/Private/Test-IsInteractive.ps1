<#
.SYNOPSIS
    Determines if the current PowerShell session is interactive.

.EXAMPLE
    Basic usage

    Test-IsInteractive
#>
function Test-IsInteractive {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $isCiRun = ($env:CI -eq 'true') -or ($env:GITHUB_ACTIONS -eq 'true')

    if ($isCiRun) {
        return $false
    }

    try {
        return [Environment]::UserInteractive -and
            -not [Console]::IsOutputRedirected -and
            -not [Console]::IsInputRedirected
    } catch {
        Write-Debug "Could not determine console interactivity. Treating session as non-interactive. $_"
        return $false
    }
}
