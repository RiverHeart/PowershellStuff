<#
.SYNOPSIS
    Removes one or more TabCentral hooks.

.DESCRIPTION
    Removes registered tab completers and result modifiers from the module-level
    tab central registry.

.EXAMPLE
    Unregister-TabCentralHook -Name Complete-WPFThis -Type Completer

.EXAMPLE
    Unregister-TabCentralHook -Name Test*

.EXAMPLE
    Unregister-TabCentralHook -All
#>
function Unregister-TabCentralHook {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateSet('Completer', 'Modifier')]
        [string] $Type,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch] $All
    )

    $Registry = Get-TabCentralRegistry

    if ($All) {
        $Registry.TabCompleters.Clear()
        $Registry.ResultModifiers.Clear()
        return
    }

    $HookTables = @()
    switch ($Type) {
        'Completer' { $HookTables += $Registry.TabCompleters }
        'Modifier'  { $HookTables += $Registry.ResultModifiers }
        default {
            $HookTables += $Registry.TabCompleters
            $HookTables += $Registry.ResultModifiers
        }
    }

    foreach ($HookTable in $HookTables) {
        foreach ($RequestedName in $Name) {
            foreach ($Key in @($HookTable.Keys)) {
                if ([string] $Key -like $RequestedName) {
                    $null = $HookTable.Remove($Key)
                }
            }
        }
    }
}
