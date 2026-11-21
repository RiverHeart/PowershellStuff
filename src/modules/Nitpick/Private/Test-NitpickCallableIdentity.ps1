<#
.SYNOPSIS
    Determines whether two rule callables represent the same implementation.

.DESCRIPTION
    Command lookup can return different wrappers for the same exported command.
    Module instance and implementation identity distinguish these from reloaded rules.
#>
function Test-NitpickCallableIdentity {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $Left,

        [Parameter(Mandatory)]
        [object] $Right
    )

    if ($Left -eq $Right) {
        return $true
    }
    if ($Left -isnot [System.Management.Automation.CommandInfo] -or
        $Right -isnot [System.Management.Automation.CommandInfo] -or
        $Left.Name -ne $Right.Name -or $Left.CommandType -ne $Right.CommandType -or
        -not [object]::ReferenceEquals($Left.Module, $Right.Module)
    ) {
        return $false
    }
    if ($Left -is [System.Management.Automation.FunctionInfo] -and
        $Right -is [System.Management.Automation.FunctionInfo]
    ) {
        return [object]::ReferenceEquals($Left.ScriptBlock, $Right.ScriptBlock)
    }
    if ($Left -is [System.Management.Automation.CmdletInfo] -and
        $Right -is [System.Management.Automation.CmdletInfo]
    ) {
        return $Left.ImplementingType -eq $Right.ImplementingType
    }
    return $false
}
