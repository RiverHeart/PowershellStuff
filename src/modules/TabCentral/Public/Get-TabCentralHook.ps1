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
        $Registry.TabCompleters |
            Where-Object { -not $Name -or $Name -like $_.Name }
    }

    if (-not $Type -or $Type -eq 'Modifier') {
        $Registry.ResultModifiers |
            Where-Object { -not $Name -or $Name -like $_.Name }
    }
}
