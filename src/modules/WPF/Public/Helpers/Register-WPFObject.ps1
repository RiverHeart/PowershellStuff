<#
.SYNOPSIS
    Returns a registered object if one exists.

.DESCRIPTION
    Returns a registered object if one exists.

    Objects are automatically registered at time of creation.

.EXAMPLE
    Register a new object.

    Register-WPFObject 'Window' $Window
#>
function Register-WPFObject {
    [CmdletBinding()]
    [Alias('Register')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [object] $InputObject,

        [switch] $Overwrite
    )

    $KeyExists = $Script:WPFControlTable.ContainsKey($Name)
    if (-not $KeyExists -or ($KeyExists -and $Overwrite)) {
        Write-Debug "Registering object named '$Name'"
        $Script:WPFControlTable[$Name] = $InputObject
    } else {
        Write-Error "Object named '$Name' already exists."
    }
}
