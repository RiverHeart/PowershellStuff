<#
.SYNOPSIS
    Finds the first WPF Path object under a node.

.DESCRIPTION
    Walks common logical child properties first (Child, Content, Children),
    then falls back to visual tree traversal. Returns the first
    System.Windows.Shapes.Path found, otherwise returns $null.

.EXAMPLE
    $Path = Find-WPFChildPath -Node $Button

    Finds the first Path under the Button's content/child hierarchy or visual tree.
#>
function Find-WPFChildPath {
    [CmdletBinding()]
    [OutputType([System.Windows.Shapes.Path])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.DependencyObject] $Node
    )

    if ($Node -is [System.Windows.Shapes.Path]) {
        return $Node
    }

    $LogicalChildren = @()

    if ($Node.PSObject.Properties.Match('Child').Count -gt 0) {
        $LogicalChildren += $Node.Child
    }

    if ($Node.PSObject.Properties.Match('Content').Count -gt 0) {
        $LogicalChildren += $Node.Content
    }

    if ($Node -is [System.Windows.Controls.Panel]) {
        $LogicalChildren += @($Node.Children)
    }

    foreach ($Child in $LogicalChildren) {
        if ($Child -is [System.Windows.DependencyObject]) {
            $Path = Find-WPFChildPath -Node $Child
            if ($Path) {
                return $Path
            }
        }
    }

    if (
        $Node -is [System.Windows.Media.Visual] -or
        $Node -is [System.Windows.Media.Media3D.Visual3D]
    ) {
        $ChildrenCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Node)
        for ($i = 0; $i -lt $ChildrenCount; $i++) {
            $Child = [System.Windows.Media.VisualTreeHelper]::GetChild($Node, $i)
            $Path = Find-WPFChildPath -Node $Child
            if ($Path) {
                return $Path
            }
        }
    }

    return $null
}
