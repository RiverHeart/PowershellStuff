using namespace System.Windows.Controls

<#
.SYNOPSIS
    Regenerates the property panel's editor rows for the current selection.

.DESCRIPTION
    Clears Panel's existing children and, if State.SelectedElement is set,
    rebuilds one expanded section per property category, with one editor row
    per Get-WpfDesignerPropertyDescriptor result. Boolean editors use a single
    CheckBox with inline content; other editors use separate label and input
    elements. Called from Select-WpfDesignerElement and
    Clear-WpfDesignerSelection so the panel always reflects the selection.
#>
function Update-WpfDesignerPropertyPanel {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Panel] $Panel,

        [Parameter(Mandatory)]
        [object] $State
    )

    $Panel.Children.Clear()

    $Selected = $State.SelectedElement
    if (-not $Selected) {
        return
    }

    $PropertyTarget = $Selected.PSObject.Properties['_WPFDesignerPropertyTarget']
    $Target = if ($PropertyTarget -and $PropertyTarget.Value) {
        $PropertyTarget.Value
    } else {
        $Selected
    }

    $DescriptorGroups = @(Get-WpfDesignerPropertyDescriptor -InputObject $Target |
            Group-Object -Property Category |
            Sort-Object -Property Name)

    foreach ($DescriptorGroup in $DescriptorGroups) {
        $CategoryPanel = [System.Windows.Controls.StackPanel]::new()
        foreach ($Descriptor in $DescriptorGroup.Group) {
            $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target
            Add-WPFObject -InputObject $CategoryPanel -ChildObjects $Editor.Elements
        }

        $CategorySection = [System.Windows.Controls.Expander]::new()
        $CategorySection.Header = if ([string]::IsNullOrWhiteSpace($DescriptorGroup.Name)) { 'Miscellaneous' } else { $DescriptorGroup.Name }
        $CategorySection.IsExpanded = $true
        $CategorySection.Content = $CategoryPanel
        $CategorySection.Margin = 0, 0, 0, 4
        $CategorySection.SetResourceReference(
            [System.Windows.FrameworkElement]::StyleProperty,
            'PropertyCategoryExpanderStyle'
        )
        $Panel.Children.Add($CategorySection) | Out-Null
    }
}
