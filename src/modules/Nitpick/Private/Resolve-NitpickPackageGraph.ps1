<#
.SYNOPSIS
    Statically resolves and validates a module's complete RuleModules declaration graph.

.DESCRIPTION
    Recursively resolves PrivateData.Linting.RuleModules declarations into a
    DirectedAcyclicGraph, without importing any module. Rejects absolute
    declaration paths, unresolvable entries, and cycles before any module is
    imported. A repeated reference to an already-visited resolved path is not
    revisited, so diamond-shaped references are deduplicated naturally.

.PARAMETER TopLevel
    The resolved Nitpick.Module descriptor for the requested top-level source.

.EXAMPLE
    Resolve-NitpickPackageGraph -TopLevel $ResolvedModule
#>
function Resolve-NitpickPackageGraph {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [psobject] $TopLevel
    )

    $Graph = [DirectedAcyclicGraph]::new()
    $Nodes = @{}

    $VisitNode = {
        param ($Descriptor)

        $NodeKey = $Descriptor.Path
        if ($Graph.ContainsNode($NodeKey)) {
            return
        }

        $Graph.AddNode($NodeKey)
        $Linting = Get-NitpickModuleLinting -Module $Descriptor -ErrorAction Stop
        $Nodes[$NodeKey] = [pscustomobject] @{
            Module = $Descriptor
            Linting = $Linting
        }

        if (-not $Linting.HasLinting) {
            return
        }

        foreach ($RuleModuleEntry in $Linting.RuleModules) {
            if ([System.IO.Path]::IsPathRooted($RuleModuleEntry)) {
                throw "Manifest '$($Descriptor.ManifestPath)' declares an absolute RuleModules path '$RuleModuleEntry'; RuleModules paths must be relative to the declaring manifest."
            }

            $DeclaringDirectory = Split-Path -Path $Descriptor.ManifestPath -Parent
            $ChildPath = Join-Path -Path $DeclaringDirectory -ChildPath $RuleModuleEntry
            try {
                $ChildDescriptor = Resolve-NitpickModuleSource -Module $ChildPath -ErrorAction Stop
            } catch {
                throw "Manifest '$($Descriptor.ManifestPath)' declares an unresolvable RuleModules entry '$RuleModuleEntry': $($_.Exception.Message)"
            }

            & $VisitNode $ChildDescriptor

            try {
                $Graph.AddEdge($NodeKey, $ChildDescriptor.Path)
            } catch [System.InvalidOperationException] {
                throw "Manifest '$($Descriptor.ManifestPath)' declares a RuleModules cycle through '$RuleModuleEntry'."
            }
        }
    }

    & $VisitNode $TopLevel

    [pscustomobject] @{
        PSTypeName = 'Nitpick.PackageGraph'
        Graph = $Graph
        Nodes = $Nodes
    }
}
