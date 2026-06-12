<#
.SYNOPSIS
    Registers a WPF object in the current context.

.DESCRIPTION
    This function registers an object in the current context. If an object
    with the same name already exists, it will not be overwritten unless the
    `-Overwrite` switch is used.

    The function also resolves the context ID based on the input object and
    the current context. If the input object is a Window, it will set the
    active context to the new window.

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

        [ValidateNotNullOrEmpty()]
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
