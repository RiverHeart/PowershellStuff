<#
.SYNOPSIS
    Creates a WPF HierarchicalDataTemplate for a TreeView or TreeViewItem.

.DESCRIPTION
    Creates a HierarchicalDataTemplate, binds its ItemsSource to the given
    child-collection property, and auto-attaches to the parent TreeView or
    TreeViewItem's ItemTemplate.

    The nested block builds the per-node visual tree using factory-mode-aware
    controls (currently TextBlock) the same way Template builds a
    ControlTemplate's visual tree. WPF applies the resulting template to every
    node in the data graph, generating TreeViewItem containers lazily instead
    of requiring manual recursion.

.EXAMPLE
    TreeView 'FileTree' {
        $this.ItemsSource = @($Root)

        HierarchicalItemTemplate 'Children' {
            TextBlock {
                BindProperty Text Header
            }
        }
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.hierarchicaldatatemplate
#>
function HierarchicalItemTemplate {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.HierarchicalDataTemplate])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $ChildrenProperty,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $ScriptBlock
    )

    $HierarchicalItemTemplate = [System.Windows.HierarchicalDataTemplate]::new()
    $HierarchicalItemTemplate.ItemsSource = [System.Windows.Data.Binding]::new($ChildrenProperty)
    Add-WPFType $HierarchicalItemTemplate 'ItemTemplate'

    # Auto-attach self to parent TreeView/TreeViewItem if one exists
    $Parent = $PSCmdlet.GetVariableValue('WPFAutoAttachContext')
    if ($Parent) {
        Write-Debug 'Beginning auto-attach for HierarchicalItemTemplate'
        Update-WPFObject $Parent $HierarchicalItemTemplate
    }

    # Factory mode: nested controls build a FrameworkElementFactory visual
    # tree instead of live instances, the same mechanism ControlTemplate uses.
    Write-Debug 'Processing factory children for HierarchicalItemTemplate'
    Update-WPFObject $HierarchicalItemTemplate $ScriptBlock

    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $Parent) {
        return $HierarchicalItemTemplate
    }
}
