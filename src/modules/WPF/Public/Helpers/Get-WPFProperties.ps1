<#
.SYNOPSIS
    Parses the contents of a scriptblock as key/value pairs
    and returns the resullts as an annotated object.

.DESCRIPTION
    Parses the contents of a scriptblock as key/value pairs
    and returns the resullts as an annotated object.

.EXAMPLE
    Properties evaluates scriptblock as key/value pairs and
    passes them to the caller which applies the results
    to the object being created.

    Button "Example" "Example" {
        Properties {
            Width = 100
            Height = 30
        }
    }
#>
function Get-WPFProperties {
    [OutputType([hashtable])]
    [Alias('Properties')]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    return $ScriptBlock.ToString() |
        ConvertFrom-StringData |
        Set-WPFObjectType -Type 'Properties' -PassThru
}
