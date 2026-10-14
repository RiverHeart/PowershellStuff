<#
.SYNOPSIS
    Acquires a rule package's declared or standalone-discovered rules.

.DESCRIPTION
    Resolves the requested module, validates it is not named the reserved Local
    namespace, statically validates its complete RuleModules declaration graph
    before importing anything, then imports only the modules needed to obtain
    declared or standalone rules. A rule-modules-only declaration never imports
    its own parent. All acquired rules are stamped with the top-level requested
    package's namespace, regardless of which nested module implements them.

.PARAMETER Module
    A module name or literal path identifying the top-level rule package source.

.EXAMPLE
    Get-NitpickPackage -Module WPF

.EXAMPLE
    Get-NitpickPackage -Module .\WPF\WPF.psd1
#>
function Get-NitpickPackage {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Module
    )

    $TopLevel = Resolve-NitpickModuleSource -Module $Module -ErrorAction Stop

    if ($TopLevel.Name -eq 'Local') {
        throw "Module package name 'Local' is reserved for explicit module-less registrations and cannot be used as a package namespace."
    }

    $PackageGraph = Resolve-NitpickPackageGraph -TopLevel $TopLevel -ErrorAction Stop
    $Namespace = $TopLevel.Name

    foreach ($NodeKey in $PackageGraph.Graph.GetTopologicalOrder()) {
        $Node = $PackageGraph.Nodes[$NodeKey]
        $NodeModule = $Node.Module
        $Linting = $Node.Linting

        $NeedsOwnImport = (-not $Linting.HasLinting) -or ($Linting.Rules.Count -gt 0)

        $ImportedInstance = $NodeModule.LoadedInstance
        if (-not $ImportedInstance -and $NeedsOwnImport) {
            # Keep path imports out of Nitpick's own discoverable module scope.
            $ImportedInstance = New-Module -ReturnResult -ArgumentList $NodeModule.Path -ScriptBlock {
                param ($ModulePath)
                $Instance = Import-Module -Name $ModulePath -Scope Local -PassThru -ErrorAction Stop
                # New-Module implicitly exports every function defined in this scriptblock's
                # dynamic module, including those Import-Module just pulled into Local scope.
                # Without suppressing that, the imported rule package's commands are exposed
                # as if they belonged to this wrapper, which both shadows the caller's own
                # same-named module and leaves its functions resolvable after Remove-Module
                # removes only the package's module-table entry. See
                # Docs/RulePackageContractStateLeak.md for the full investigation.
                Export-ModuleMember -Function @() -Alias @()
                $Instance
            } -ErrorAction Stop
        }

        if (-not $Linting.HasLinting) {
            if (-not $ImportedInstance) {
                continue
            }
            $ImportedInstance.ExportedCommands.Values |
                Where-Object { $_.Name -like 'Test-*' -or $_.Name -like 'Measure-*' } |
                Where-Object { $_.Parameters.Keys -contains 'ScriptBlockAst' } |
                ForEach-Object {
                    New-Nitpick -Namespace $Namespace -Callable $_ -ErrorAction Stop
                }
            continue
        }

        foreach ($RuleName in $Linting.Rules) {
            $Command = $ImportedInstance.ExportedCommands[$RuleName]
            if (-not $Command) {
                throw "Manifest '$($NodeModule.ManifestPath)' declares Rules entry '$RuleName', but it is not an exported command on '$($NodeModule.Name)'."
            }
            try {
                Assert-CallableSignature -Callable $Command -RequiredParams 'ScriptBlockAst' -ErrorAction Stop
            } catch {
                throw "Manifest '$($NodeModule.ManifestPath)' declares Rules entry '$RuleName', but it is not a compatible Nitpick rule: $($_.Exception.Message)"
            }
            New-Nitpick -Namespace $Namespace -Callable $Command -ErrorAction Stop
        }
    }
}
