<#
.SYNOPSIS
    Adds a custom type to objects for the DSL to distinguish them.

.DESCRIPTION
    Adds a custom type to objects for the DSL to distinguish them.

    Other functions such as `Update-WPFObject` use this type
    to decide how scriptblock results should be applied to objects
    being created.

    This function also ensures that type are only set to
    supported values and will error on typos.

.EXAMPLE
    Annotate 'Window' object as a 'Control'.

    $Window = [System.Windows.Window] @{
        Title = $Title
        Height = $Height
        Width = $Width
    }
    Add-WPFType 'Control'
#>
function Add-WPFType {
    [CmdletBinding()]
    [OutputType([void], [object])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Control', 'Handler', 'Shape', 'GridDefinition',
            'Command'
        )]
        [string] $Type,

        [switch] $PassThru
    )

    begin {
        $PSTypeName = "Custom.WPF.$Type"
    }

    process {
        foreach($Item in $InputObject) {
            if ($PSTypeName -notin $Item.PSObject.TypeNames) {
                $Item.PSObject.TypeNames.Insert(0, $PSTypeName)
            }
            if ($PassThru) {
                Write-Output $Item
            }
        }
    }
}
