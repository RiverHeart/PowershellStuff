<#
.SYNOPSIS
    Returns a registered object by name.

.DESCRIPTION
    Returns a registered object by name.

    Objects are automatically registered at time of creation.

.NOTES
    It's not necessary to specify the type when assigning a reference to a variable,
    as PowerShell will infer the type from the registered object. However, it is recommended
    that you do so to take advantage of IntelliSense or ensure you're getting the object
    you think you are.

.EXAMPLE
    Get reference to the Window

    [System.Windows.Window] $Window = Reference 'Window'
#>
function Reference {
    [CmdletBinding()]
    [Alias('Get-WPFRegisteredObject')]
    [OutputType([void], [object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [ArgumentCompleter({ Complete-WPFRegisteredObject @args })]
        [string[]] $Name,

        [Parameter(HelpMessage = 'Optionally specify a property to select from the registered object. If not specified, the entire object will be returned.')]
        [string] $Property
    )

    process {
        foreach($Item in $Name) {
            if ($Script:WPFControlTable.ContainsKey($Item)) {
                if ($Property) {
                    $Script:WPFControlTable[$Item] | Select-Object -ExpandProperty $Property
                } else {
                    $Script:WPFControlTable[$Item]
                }
            } else {
                Write-Error "No object registered with name '$Item'"
                return
            }
        }
    }
}
