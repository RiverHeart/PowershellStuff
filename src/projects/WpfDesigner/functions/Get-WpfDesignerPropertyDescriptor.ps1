<#
.SYNOPSIS
    Returns writable, browsable properties of an object for a property panel.

.DESCRIPTION
    Uses TypeDescriptor.GetProperties with a Browsable(true) filter - the
    same default-attribute mechanism WinForms' PropertyGrid relies on - so
    properties hidden via [Browsable(false)] are excluded without a
    hand-maintained allow/deny list. PropertyDescriptor.IsReadOnly further
    excludes properties with no setter or an explicit [ReadOnly(true)].

    Only properties whose type maps to a known Get-WpfDesignerEditorKind
    value are returned; anything else (Brush, Thickness, etc.) is skipped
    until a dedicated editor exists for it.
#>
function Get-WpfDesignerPropertyDescriptor {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    $Filter = [Attribute[]] @([System.ComponentModel.BrowsableAttribute]::Yes)
    $Properties = [System.ComponentModel.TypeDescriptor]::GetProperties($InputObject, $Filter)

    # Powershell fails to implicitly enumerate PropertyDescriptorCollection via foreach
    # so an explicit call to `GetEnumerator()` is necessary here
    foreach ($Property in $Properties.GetEnumerator()) {
        if ($Property.IsReadOnly) {
            continue
        }

        $EditorKind = Get-WpfDesignerEditorKind -PropertyType $Property.PropertyType
        if (-not $EditorKind) {
            continue
        }

        [pscustomobject] @{
            Name         = $Property.Name
            PropertyType = $Property.PropertyType
            Category     = $Property.Category
            EditorKind   = $EditorKind
        }
    }
}
