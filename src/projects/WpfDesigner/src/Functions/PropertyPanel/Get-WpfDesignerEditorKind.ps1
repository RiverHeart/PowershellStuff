<#
.SYNOPSIS
    Classifies a property type into a property panel editor kind.

.DESCRIPTION
    Returns one of 'Text', 'Number', 'Bool', 'Enum' for types the property
    panel knows how to render, or $null for anything else. Keeping this a
    small closed set of kinds (rather than per-control-type templates) is
    what lets the panel's template count stay flat as more control types
    gain support.
#>
function Get-WpfDesignerEditorKind {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [type] $PropertyType
    )

    if ($PropertyType.IsEnum) {
        return 'Enum'
    }

    switch ($PropertyType) {
        ([string]) { return 'Text' }
        ([bool]) { return 'Bool' }
        ([byte]) { return 'Number' }
        ([sbyte]) { return 'Number' }
        ([int16]) { return 'Number' }
        ([uint16]) { return 'Number' }
        ([int32]) { return 'Number' }
        ([uint32]) { return 'Number' }
        ([int64]) { return 'Number' }
        ([uint64]) { return 'Number' }
        ([single]) { return 'Number' }
        ([double]) { return 'Number' }
        ([decimal]) { return 'Number' }
    }

    return $null
}
