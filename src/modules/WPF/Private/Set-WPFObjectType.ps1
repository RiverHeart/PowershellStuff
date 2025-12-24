<#
.SYNOPSIS
    Sets the WPF_TYPE property on objects to distinguish them.

.DESCRIPTION
    Sets the WPF_TYPE property on objects to distinguish them.

    Other functions such as `Update-WPFObject` use this annotation
    to decide how scriptblock results should be applied to objects
    being created.

    This function also ensures that annotations are only set to
    supported values and will error on typos.

.EXAMPLE
    Annotate 'Window' object as a 'Control'.

    $Window = [System.Windows.Window] @{
        Title = $Title
        Height = $Height
        Width = $Width
    }
    Set-WPFObjectType 'Control'
#>
function Set-WPFObjectType {
    [CmdletBinding()]
    [OutputType([void], [object])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet('Control', 'Properties', 'Handler')]
        [string] $Type,

        [switch] $PassThru
    )

    process {
        foreach($Item in $InputObject) {
            Add-Member `
                -InputObject $Item `
                -MemberType NoteProperty `
                -Name 'WPF_TYPE' `
                -Value $Type `
                -PassThru:$PassThru
        }
    }
}
