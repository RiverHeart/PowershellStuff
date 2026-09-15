<#
.SYNOPSIS
    Resets TabCentral hook state.

.DESCRIPTION
    Clears all registered tab expansion hooks from the module-level registry.
    Optionally restores the original global TabExpansion2 function if one was
    captured when TabCentral imported.

.EXAMPLE
    Reset-TabExpansion2

.EXAMPLE
    Reset-TabExpansion2 -RestoreOriginal -PassThru
#>
function Reset-TabExpansion2 {
    [CmdletBinding()]
    [OutputType([void], [pscustomobject])]
    param(
        [switch] $RestoreOriginal,

        [switch] $PassThru
    )

    $Registry = Get-TabCentralRegistry
    $Registry.TabCompleters.Clear()
    $Registry.ResultModifiers.Clear()

    if ($RestoreOriginal -and $script:OriginalTabExpansion2) {
        Set-Item -Path Function:\global:TabExpansion2 -Value $script:OriginalTabExpansion2 -Force
    }

    if ($PassThru) {
        return Get-TabCentralHook
    }
}
