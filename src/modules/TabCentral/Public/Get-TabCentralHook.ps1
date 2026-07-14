<#
.SYNOPSIS
    Returns registered TabCentral hooks.

.DESCRIPTION
    Lists custom tab completers and result modifiers from the module-level
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
        [ValidateSet('Completer', 'Modifier')]
        [string] $Type,

        [string[]] $Name
    )

    $Registry = Get-TabCentralRegistry

    $HookTables = @()
    switch ($Type) {
        'Completer' {
            $HookTables += [pscustomobject] @{
                Type = 'Completer'
                Table = $Registry.TabCompleters
            }
        }
        'Modifier' {
            $HookTables += [pscustomobject] @{
                Type = 'Modifier'
                Table = $Registry.ResultModifiers
            }
        }
        default {
            $HookTables += [pscustomobject] @{
                Type = 'Completer'
                Table = $Registry.TabCompleters
            }
            $HookTables += [pscustomobject] @{
                Type = 'Modifier'
                Table = $Registry.ResultModifiers
            }
        }
    }

    foreach ($HookTable in $HookTables) {
        foreach ($Entry in $HookTable.Table.GetEnumerator()) {
            $MatchesName = $true
            if ($Name) {
                $MatchesName = $false
                foreach ($RequestedName in $Name) {
                    if ([string] $Entry.Key -like $RequestedName) {
                        $MatchesName = $true
                        break
                    }
                }
            }

            if (-not $MatchesName) {
                continue
            }

            [pscustomobject] @{
                Name = [string] $Entry.Key
                Type = $HookTable.Type
                ScriptBlock = [scriptblock] $Entry.Value
            }
        }
    }
}
