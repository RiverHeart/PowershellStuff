using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
    Finds valid Nitpick rules exported by loaded modules, or acquires a rule
    package from an explicit module name or literal path.

.DESCRIPTION
    Finds exported Test and Measure commands with the required Nitpick callable
    signature. Selected modules and their nested modules are searched. Only
    modules already loaded in the current session are inspected by default.
    Removed nested modules and temporary module scopes are not traversed.

    A string entry in Module is resolved and acquired as an explicit rule
    package instead: its declared PrivateData.Linting is read, its RuleModules
    declaration graph is statically validated before anything is imported, and
    the resulting identity-bearing NitpickRule descriptors are stamped with
    that top-level package's namespace. A module with no Linting declaration
    contributes only its own standalone-compatible exported commands.

.PARAMETER Module
    Exact module objects to inspect instead of the default loaded-module roots,
    or module names/literal paths to acquire as explicit rule packages.
    IncludeModule and ExcludeModule filter only the module-object root names.

.EXAMPLE
    Returns all valid Nitpick rules from the currently loaded modules.

    Find-Nitpick

.EXAMPLE
    Returns all valid Nitpick rules from the specified modules.

    Find-Nitpick -IncludeModule Nitpick, MyNitpickRules

.EXAMPLE
    Acquires an explicit rule package by name or literal path.

    Find-Nitpick -Module WPF

.EXAMPLE
    Pipes the output of Find-Nitpick to Register-Nitpick.

    Find-Nitpick | Register-Nitpick
#>
function Find-Nitpick {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandInfo])]
    [OutputType([object])]
    param(
        [string[]] $Name,

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,

        [string[]] $IncludeModule,
        [string[]] $ExcludeModule,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -is [string] -or $_ -is [PSModuleInfo] })]
        [object[]] $Module
    )

    $DefaultInclude = @('Test-*', 'Measure-*')
    $PSModuleInfoEntries = @($Module | Where-Object { $_ -is [PSModuleInfo] })
    $StringEntries = @($Module | Where-Object { $_ -is [string] })

    $LoadedModules = [HashSet[PSModuleInfo]]::new()
    Get-Module -All | ForEach-Object {
        $null = $LoadedModules.Add($_)
    }
    $RootModules = if ($PSBoundParameters.ContainsKey('Module')) { $PSModuleInfoEntries } else { Get-Module }
    $PendingModules = [Queue[PSModuleInfo]]::new()
    $RootModules |
        Where-NitpickIncluded `
            -PropertyPath Name `
            -Include $IncludeModule `
            -Exclude $ExcludeModule `
            -Wildcard |
        ForEach-Object {
            $PendingModules.Enqueue($_)
        }

    $VisitedModules = [HashSet[PSModuleInfo]]::new()
    $DiscoveredCommands = [HashSet[CommandInfo]]::new()

    while ($PendingModules.Count -gt 0) {
        $CurrentModule = $PendingModules.Dequeue()
        if (-not $VisitedModules.Add($CurrentModule)) {
            continue
        }

        $CurrentModule.NestedModules | ForEach-Object {
            if ($LoadedModules.Contains($_)) {
                $PendingModules.Enqueue($_)
            }
        }

        $CurrentModule.ExportedCommands.Values |
            Where-Object {
                $Command = $_
                $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }

                $IncludePatterns = if ($IncludeRule) { $IncludeRule } else { $DefaultInclude }
                $IncludeValue = if ($IncludeRule) { $RuleName } else { $Command.Name }
                $IsIncluded = $IncludePatterns | Where-Object { $IncludeValue -like $_ }
                $IsExcluded = $ExcludeRule | Where-Object { $RuleName -like $_ }

                if (-not $IsIncluded -or $IsExcluded) {
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
                # Returns true for new items, false for duplicates.
                $DiscoveredCommands.Add($_)
            }
    }

    foreach ($Entry in $StringEntries) {
        try {
            $PackageRules = Get-NitpickPackage -Module $Entry -ErrorAction Stop
        } catch {
            Write-Error -ErrorRecord $_
            continue
        }

        $PackageRules |
            Where-NitpickIncluded -PropertyPath Name -Include $IncludeRule -Exclude $ExcludeRule -Wildcard |
            Where-NitpickIncluded -PropertyPath Name -Include $Name -Wildcard
    }
}
