<#
.SYNOPSIS
    Returns registered TabCentral hooks.

.DESCRIPTION
    Lists custom tab completers and result modifiers in the
    tab central registry.

.EXAMPLE
    Get-TabCentralHook

.EXAMPLE
    Get-TabCentralHook -Type Completer -Name Complete-Example
#>
function Get-TabCentralHook {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]] $Name,

        [ValidateSet('Completer', 'Modifier')]
        [string] $Type
    )

    $Registry = Get-TabCentralRegistry

    if (-not $Type -or $Type -eq 'Completer') {
        $Registry.TabCompleters.Values |
            Where-Object {
                $HookName = $_.Name
                -not $Name -or @($Name | Where-Object { $HookName -like $_ }).Count -gt 0
            }
    }

    if (-not $Type -or $Type -eq 'Modifier') {
        $Registry.ResultModifiers.Values |
            Where-Object {
                $HookName = $_.Name
                -not $Name -or @($Name | Where-Object { $HookName -like $_ }).Count -gt 0
            }
    }
}
