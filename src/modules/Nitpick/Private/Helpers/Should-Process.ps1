<#
.SYNOPSIS
    Wrapper for `$PSCmdlet.ShouldProcess` that can be mocked in tests.

.DESCRIPTION
    Wrapper for `$PSCmdlet.ShouldProcess` that can be mocked in tests.

    The `WHATIF__QUIET` environment variable can be used to simulate WhatIf
    behavior in tests without producing console output. When WhatIf is inactive,
    normal confirmation behavior is preserved.

.NOTES
    This function is necessary because `$PSCmdlet.ShouldProcess` cannot be
    easily mocked in tests nor can the "What if: foo" console output be
    suppressed because it bypasses the normal output streams by calling
    `$Host.UI.WriteLine`.

.EXAMPLE
    Basic usage

    Should-Process -Target 'C:\path\to\target' -Action 'Write rendered AST overlay output'
#>
function Should-Process {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [string] $Action
    )

    if ($env:WHATIF__QUIET -eq $true -and $WhatIfPreference -eq $true) {
        return $false
    }
    return $PSCmdlet.ShouldProcess($Target, $Action)
}
