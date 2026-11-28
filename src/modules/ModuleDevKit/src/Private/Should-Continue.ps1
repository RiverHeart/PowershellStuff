<#
.SYNOPSIS
    Wrapper for `$PSCmdlet.ShouldContinue` that can be tested independently.

.DESCRIPTION
    Prompts the user to continue an operation. Keeping this call in a wrapper
    makes it possible to test callers without mocking a `$PSCmdlet` method.

.PARAMETER Message
    Explanation presented to the user.

.PARAMETER Caption
    Short title for the confirmation prompt.

.PARAMETER Force
    Returns true without prompting.

.EXAMPLE
    Should-Continue -Message 'Continue packaging without ignore filtering?' -Caption 'Git unavailable'
#>
function Should-Continue {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [string] $Caption,

        [switch] $Force
    )

    if ($Force) {
        Write-Output $true
        return
    }

    $Decision = $PSCmdlet.ShouldContinue($Message, $Caption)
    Write-Output -InputObject $Decision
}
