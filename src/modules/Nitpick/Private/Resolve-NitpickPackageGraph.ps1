<#
.SYNOPSIS
    Statically resolves and validates a module's complete RuleModules declaration graph.

.DESCRIPTION
    Recursively resolves PrivateData.Linting.RuleModules declarations into a
    DirectedAcyclicGraph, without importing any module. Rejects absolute
    declaration paths, unresolvable entries, and cycles before any module is
    imported. Supporting modules must declare a reciprocal OwnerModule path;
    ownership links are resolved and validated before imports. A repeated
    reference to an already-visited resolved path is not revisited, so
    diamond-shaped references are deduplicated naturally.

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
    $Parents = @{}
    $GetIdentityPath = {
        param ($Module)
        if ($Module.ManifestPath) { $Module.ManifestPath } else { $Module.Path }
    }

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
            Namespace = $null
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

            if (-not $Parents.ContainsKey($ChildDescriptor.Path)) {
                $Parents[$ChildDescriptor.Path] = @{}
            }
            $ParentIdentityPath = & $GetIdentityPath $Descriptor
            $Parents[$ChildDescriptor.Path][$ParentIdentityPath] = $Descriptor

            & $VisitNode $ChildDescriptor

            try {
                $Graph.AddEdge($NodeKey, $ChildDescriptor.Path)
            } catch [System.InvalidOperationException] {
                throw "Manifest '$($Descriptor.ManifestPath)' declares a RuleModules cycle through '$RuleModuleEntry'."
            }
        }
    }

    & $VisitNode $TopLevel

    foreach ($NodeKey in $Graph.GetTopologicalOrder()) {
        $Node = $Nodes[$NodeKey]
        $Descriptor = $Node.Module
        $Linting = $Node.Linting
        $DeclaredParents = $Parents[$NodeKey]
        $Owner = $null

        if ($Linting.OwnerModule) {
            if ([System.IO.Path]::IsPathRooted($Linting.OwnerModule)) {
                throw "Manifest '$($Descriptor.ManifestPath)' declares an absolute OwnerModule path '$($Linting.OwnerModule)'; OwnerModule paths must be relative to the supporting manifest."
            }

            $SupportingDirectory = Split-Path -Path $Descriptor.ManifestPath -Parent
            $OwnerPath = Join-Path -Path $SupportingDirectory -ChildPath $Linting.OwnerModule
            try {
                $Owner = Resolve-NitpickModuleSource -Module $OwnerPath -ErrorAction Stop
            } catch {
                throw "Manifest '$($Descriptor.ManifestPath)' declares an unresolvable OwnerModule entry '$($Linting.OwnerModule)': $($_.Exception.Message)"
            }

            $NodeIdentityPath = & $GetIdentityPath $Descriptor
            $OwnerIdentityPath = & $GetIdentityPath $Owner
            if ($OwnerIdentityPath -ieq $NodeIdentityPath) {
                throw "Manifest '$($Descriptor.ManifestPath)' cannot declare itself as OwnerModule."
            }
            if ($Owner.Name -eq 'Local') {
                throw "Manifest '$($Descriptor.ManifestPath)' cannot use the reserved Local module as its owner."
            }
            if ($DeclaredParents.Count -gt 0 -and -not $DeclaredParents.ContainsKey($OwnerIdentityPath)) {
                throw "Manifest '$($Descriptor.ManifestPath)' declares OwnerModule '$($Linting.OwnerModule)', but that module does not declare this supporting module in RuleModules."
            }

            $OwnerLinting = Get-NitpickModuleLinting -Module $Owner -ErrorAction Stop
            $IsReciprocallyDeclared = $false
            foreach ($OwnerRuleModule in $OwnerLinting.RuleModules) {
                if ([System.IO.Path]::IsPathRooted($OwnerRuleModule)) {
                    throw "Manifest '$($Owner.ManifestPath)' declares an absolute RuleModules path '$OwnerRuleModule'; RuleModules paths must be relative to the declaring manifest."
                }

                $OwnerDirectory = Split-Path -Path $Owner.ManifestPath -Parent
                $ReciprocalPath = Join-Path -Path $OwnerDirectory -ChildPath $OwnerRuleModule
                try {
                    $ReciprocalModule = Resolve-NitpickModuleSource -Module $ReciprocalPath -ErrorAction Stop
                } catch {
                    throw "Manifest '$($Owner.ManifestPath)' declares an unresolvable RuleModules entry '$OwnerRuleModule': $($_.Exception.Message)"
                }

                $ReciprocalIdentityPath = & $GetIdentityPath $ReciprocalModule
                if ($NodeIdentityPath -ieq $ReciprocalIdentityPath) {
                    $IsReciprocallyDeclared = $true
                    break
                }
            }

            if (-not $IsReciprocallyDeclared) {
                throw "Manifest '$($Descriptor.ManifestPath)' declares OwnerModule '$($Linting.OwnerModule)', but '$($Owner.ManifestPath)' does not reciprocally declare it in RuleModules."
            }

            $Node.Namespace = $Owner.Name
        } elseif ($DeclaredParents.Count -gt 0) {
            $ParentNames = @($DeclaredParents.Values | ForEach-Object Name)
            $ParentList = $ParentNames -join ', '
            throw "Manifest '$($Descriptor.ManifestPath)' is declared as a supporting rule module by '$ParentList' but does not declare Linting.OwnerModule."
        } else {
            $Node.Namespace = $Descriptor.Name
        }
    }

    [pscustomobject] @{
        PSTypeName = 'Nitpick.PackageGraph'
        Graph = $Graph
        Nodes = $Nodes
    }
}
