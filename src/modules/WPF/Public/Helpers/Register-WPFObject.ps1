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
        # Only allow letters, numbers, and underscores
        [Parameter(Mandatory)]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [object] $InputObject,

        [switch] $Overwrite
    )

    $Type = $InputObject.GetType().Name
    $KeyExists = $Script:WPFControlTable.ContainsKey($Name)
    if (-not $KeyExists -or ($KeyExists -and $Overwrite)) {
        Write-Debug "Registering object '$Type' as '$Name'"
        $Script:WPFControlTable[$Name] = $InputObject
    } elseif ($Script:WPFControlTable[$Name] -eq $InputObject) {
        Write-Warning "Object '$Type' already registered as '$Name'."
    } else {
        Write-Error "Another object registered as '$Name' already exists."
    }
}
