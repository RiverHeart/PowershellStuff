<#
.SYNOPSIS
    Finds child dependency objects under a WPF node.

.DESCRIPTION
    Walks common logical child properties first (Child, Content, Children),
    then falls back to visual tree traversal.

    By default, returns the first node matching the requested type.
    Use -All to return all matching nodes discovered during traversal.

.EXAMPLE
    $Path = Find-WPFChildNode -Node $Button -Type ([System.Windows.Shapes.Path])

    Finds the first Path under the Button's content/child hierarchy or visual tree.

.EXAMPLE
    $Buttons = Find-WPFChildNode -Node $StackPanel -Type ([System.Windows.Controls.Button]) -All

    Returns all Button descendants under the StackPanel.
#>
function Find-WPFChildNode {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.DependencyObject], [System.Windows.DependencyObject[]])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.DependencyObject] $Node,

        [Parameter()]
        [Type] $Type = [System.Windows.DependencyObject],

        [switch] $All
    )

    $Results = [System.Collections.Generic.List[System.Windows.DependencyObject]]::new()
    $Visited = [System.Collections.Generic.HashSet[int]]::new()

    function Find-WPFChildNodeRecursive {
        param(
            [Parameter(Mandatory)]
            [System.Windows.DependencyObject] $CurrentNode
        )

        $NodeId = [System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($CurrentNode)
        if (-not $Visited.Add($NodeId)) {
            return $false
        }

        if ($CurrentNode -is $Type) {
            $Results.Add($CurrentNode)
            if (-not $All) {
                return $true
            }
        }

        $LogicalChildren = [System.Collections.Generic.List[System.Windows.DependencyObject]]::new()

        if ($CurrentNode.PSObject.Properties.Match('Child').Count -gt 0 -and
            $CurrentNode.Child -is [System.Windows.DependencyObject]
        ) {
            $LogicalChildren.Add($CurrentNode.Child)
        }

        if ($CurrentNode.PSObject.Properties.Match('Content').Count -gt 0 -and
            $CurrentNode.Content -is [System.Windows.DependencyObject]
        ) {
            $LogicalChildren.Add($CurrentNode.Content)
        }

        if ($CurrentNode -is [System.Windows.Controls.Panel]) {
            foreach ($Child in $CurrentNode.Children) {
                if ($Child -is [System.Windows.DependencyObject]) {
                    $LogicalChildren.Add($Child)
                }
            }
        }

        foreach ($Child in $LogicalChildren) {
            if (Find-WPFChildNodeRecursive -CurrentNode $Child) {
                return $true
            }
        }

        if (
            $CurrentNode -is [System.Windows.Media.Visual] -or
            $CurrentNode -is [System.Windows.Media.Media3D.Visual3D]
        ) {
            $ChildrenCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($CurrentNode)
            for ($i = 0; $i -lt $ChildrenCount; $i++) {
                $Child = [System.Windows.Media.VisualTreeHelper]::GetChild($CurrentNode, $i)
                if ($Child -is [System.Windows.DependencyObject] -and (Find-WPFChildNodeRecursive -CurrentNode $Child)) {
                    return $true
                }
            }
        }

        return $false
    }

    [void] (Find-WPFChildNodeRecursive -CurrentNode $Node)

    if ($All) {
        return $Results.ToArray()
    }

    if ($Results.Count -gt 0) {
        return $Results[0]
    }

    return $null
}
