<#
.SYNOPSIS
    Determines whether the current PowerShell session can prompt the user.

.DESCRIPTION
    Guided fix mode reads selections from the host, so it must not run when the
    host was started with -NonInteractive (or an abbreviation such as -NonI).
    Kept as a separate function so tests can mock it in non-interactive runners.

.EXAMPLE
    Test-NitpickInteractiveSession
#>
function Test-NitpickInteractiveSession {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $NonInteractiveArguments = @([Environment]::GetCommandLineArgs() -match '^-noni')
    return $NonInteractiveArguments.Count -eq 0
}
