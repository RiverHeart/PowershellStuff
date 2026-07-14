<#
.SYNOPSIS
    Resets WPF TabExpansion2 hook state.

.DESCRIPTION
    Clears all registered tab expansion hooks from the module-level registry,
    optionally restores the original global TabExpansion2 function, and re-registers
    the default WPF completer hook unless disabled.

.EXAMPLE
    Reset-TabExpansion2

.EXAMPLE
    Reset-TabExpansion2 -NoDefaultHooks

.EXAMPLE
    Reset-TabExpansion2 -RestoreOriginal -PassThru
#>
function Reset-TabExpansion2 {
    [CmdletBinding()]
    [OutputType([void], [pscustomobject])]
    param(
        [switch] $RestoreOriginal,

        [switch] $NoDefaultHooks,

        [switch] $PassThru
    )

    $Registry = Get-WPFTabExpansionRegistry
    $Registry.TabCompleters.Clear()
    $Registry.ResultModifiers.Clear()

    if ($RestoreOriginal -and (Get-Command OriginalTabExpansion2 -ErrorAction SilentlyContinue)) {
        Copy-Item -Path Function:\script:OriginalTabExpansion2 -Destination Function:\global:TabExpansion2 -Force
    }

    if ((-not $NoDefaultHooks) -and (-not $RestoreOriginal)) {
        Register-TabExpansionHook -FunctionName 'Complete-WPFThis' -Type Completer -Force
    } elseif ($RestoreOriginal -and (-not $NoDefaultHooks)) {
        Write-Verbose 'Skipping default WPF hook registration because -RestoreOriginal was specified.'
    }

    if ($PassThru) {
        return Get-TabExpansionHook
    }
}
