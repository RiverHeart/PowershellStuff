<#
.SYNOPSIS
    Parses the contents of a scriptblock as key/value pairs
    and returns the resullts as an annotated object.

.DESCRIPTION
    Parses the contents of a scriptblock as key/value pairs
    and returns the resullts as an annotated object.

.NOTES
    As much as I dislike change in syntax, passing and returning
    a hashtable is the simplest and most sensible solution I can
    see to property setting.

    I played with the code below to parse key/value pairs from the
    scriptblock and it works fine but you lose functions/variables
    and the editor gets all complainy because it interprets words
    as functions.

    ```
    return $ScriptBlock.ToString() |
        ConvertFrom-StringData |
        Set-WPFObjectType -Type 'Properties' -PassThru
    ```

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
function Get-WPFPropertyTable {
    [OutputType([hashtable])]
    [Alias('Properties')]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Hashtable
    )

    return $Hashtable | Set-WPFObjectType -Type 'Properties' -PassThru
}
