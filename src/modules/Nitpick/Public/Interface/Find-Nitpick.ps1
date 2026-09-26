<#
.SYNOPSIS
    Finds valid Nitpick rules exported by loaded modules.

.DESCRIPTION
    Finds exported Test and Measure commands with the required Nitpick callable
    signature. Selected modules and their nested modules are searched. Only
    modules already loaded in the current session are inspected.

.EXAMPLE
    Returns all valid Nitpick rules from the currently loaded modules.

    Find-Nitpick

.EXAMPLE
    Returns all valid Nitpick rules from the specified modules.

    Find-Nitpick -Module Nitpick, MyNitpickRules

.EXAMPLE
    Pipes the output of Find-Nitpick to Register-Nitpick.

    Find-Nitpick | Register-Nitpick
#>
function Find-Nitpick {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandInfo])]
    param(
        [string[]] $Name,
        [string[]] $Module
    )

    $GetModuleParams = @{}
    if ($Module) {
        $GetModuleParams.Name = $Module
    }

    $PendingModules = [System.Collections.Generic.Queue[System.Management.Automation.PSModuleInfo]]::new()
    Get-Module @GetModuleParams | ForEach-Object {
        $PendingModules.Enqueue($_)
    }

    $VisitedModules = [System.Collections.Generic.HashSet[System.Management.Automation.PSModuleInfo]]::new()
    $DiscoveredCommands = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    while ($PendingModules.Count -gt 0) {
        $CurrentModule = $PendingModules.Dequeue()
        if (-not $VisitedModules.Add($CurrentModule)) {
            continue
        }

        $CurrentModule.NestedModules | ForEach-Object {
            $PendingModules.Enqueue($_)
        }

        $CurrentModule.ExportedCommands.Values |
            Where-Object {
                $Command = $_

                if ($Command.Verb -notin 'Test', 'Measure') {
                    return $false
                }

                if ($Command.Parameters.Keys -notcontains 'ScriptBlockAst') {
                    return $false
                }

                if (-not $Name) {
                    return $true
                }

                return [bool] ($Name | Where-Object {
                    $Command.Name -like $_
                })
            } |
            Where-Object {
                $CommandIdentity = '{0}|{1}|{2}|{3}' -f @(
                    $_.Module.Guid
                    $_.Module.Version
                    $_.Module.Path
                    $_.Name
                )
                # Returns true for new items, false for duplicates.
                $DiscoveredCommands.Add($CommandIdentity)
            }
    }
}
