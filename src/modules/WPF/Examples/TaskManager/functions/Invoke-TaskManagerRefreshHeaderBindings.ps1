function Invoke-TaskManagerRefreshHeaderBindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.DataGrid] $DataGrid
    )

    function Get-TaskManagerHeaderPresenter {
        param(
            [Parameter(Mandatory)]
            [System.Windows.DependencyObject] $Node
        )

        if ($Node -is [System.Windows.Controls.Primitives.DataGridColumnHeadersPresenter]) {
            return $Node
        }

        $childCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Node)
        for ($index = 0; $index -lt $childCount; $index++) {
            $found = Get-TaskManagerHeaderPresenter -Node ([System.Windows.Media.VisualTreeHelper]::GetChild($Node, $index))
            if ($null -ne $found) {
                return $found
            }
        }

        return $null
    }

    function Update-TaskManagerTextBlockBindingTarget {
        param(
            [Parameter(Mandatory)]
            [System.Windows.DependencyObject] $Node,

            [ref] $UpdatedCount
        )

        if ($Node -is [System.Windows.Controls.TextBlock]) {
            $bindingExpression = [System.Windows.Data.BindingOperations]::GetBindingExpression(
                $Node,
                [System.Windows.Controls.TextBlock]::TextProperty
            )

            if ($null -ne $bindingExpression) {
                $bindingExpression.UpdateTarget()
                $UpdatedCount.Value++
            }
        }

        $childCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Node)
        for ($index = 0; $index -lt $childCount; $index++) {
            Update-TaskManagerTextBlockBindingTarget -Node ([System.Windows.Media.VisualTreeHelper]::GetChild($Node, $index)) -UpdatedCount $UpdatedCount
        }
    }

    $headerPresenter = Get-TaskManagerHeaderPresenter -Node $DataGrid

    if ($null -eq $headerPresenter) {
        # Header visuals may not exist yet if layout has not been realized.
        Write-Debug 'TaskManager header refresh skipped: no DataGridColumnHeadersPresenter visual found yet.'
        return
    }

    $updatedCount = 0
    Update-TaskManagerTextBlockBindingTarget -Node $headerPresenter -UpdatedCount ([ref] $updatedCount)
    Write-Debug ("TaskManager header refresh updated {0} TextBlock binding target(s)." -f $updatedCount)
}