<#
.SYNOPSIS
    Checks if a specific assembly is loaded in the current AppDomain.

.DESCRIPTION
    This function queries the current AppDomain for loaded assemblies and returns
    a boolean indicating whether the specified assembly is loaded.

.EXAMPLE
    Test if "System.Core" is loaded in the current AppDomain.

    Test-AssemblyLoaded -Name "System.Core"
#>
function Test-AssemblyLoaded {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )
    process {
        $assembly = [System.AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GetName().Name -eq $Name }

        return $null -ne $assembly
    }
}
