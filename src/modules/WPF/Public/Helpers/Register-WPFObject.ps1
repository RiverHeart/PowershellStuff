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

        [string] $ContextId,

        [switch] $Overwrite
    )

    $Parent = $PSCmdlet.GetVariableValue('this')
    $ResolvedContextId = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $InputObject -CreateIfMissing -Name $Name
    if (-not $ResolvedContextId -and $Parent) {
        $ResolvedContextId = Resolve-WPFControlContextId -InputObject $Parent -CreateIfMissing -Name $Name
    }

    if (-not $ResolvedContextId) {
        $ResolvedContextId = New-WPFControlContext -Name $Name -Activate
    }

    $ControlTable = Get-WPFControlTable -ContextId $ResolvedContextId -CreateIfMissing -Name $Name
    Set-WPFControlContext -InputObject $InputObject -ContextId $ResolvedContextId

    if ($InputObject -is [System.Windows.Window]) {
        Set-WPFControlActiveContext -ContextId $ResolvedContextId
    }

    $Type = $InputObject.GetType().Name
    $KeyExists = $ControlTable.ContainsKey($Name)
    if (-not $KeyExists -or ($KeyExists -and $Overwrite)) {
        Write-Debug "Registering object '$Type' as '$Name' in context '$ResolvedContextId'"
        $ControlTable[$Name] = $InputObject
    } elseif ($ControlTable[$Name] -eq $InputObject) {
        Write-Warning "Object '$Type' already registered as '$Name' in context '$ResolvedContextId'."
    } else {
        Write-Error "Another object registered as '$Name' already exists in context '$ResolvedContextId'."
    }
}
