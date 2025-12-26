<#
.SYNOPSIS
    Retrieve raw arguments passed to TabExpansion2

.DESCRIPTION
    Retrieve raw arguments passed to TabExpansion2

    Filters the callstack for the first instance of TabExpansion2
    being called and returns the bound parameters.

.EXAMPLE
    Get params passed to TabExpansion2

    $Params = Get-FunctionParams TabExpansion2
    $Params.Keys | Out-Host
#>
function Get-WPFFunctionParam {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Command,

        [string[]] $Include,
        [string[]] $Exclude
    )


    # Get TabExpansion2 raw arguments
    $Callstack = Get-PSCallStack | Where-Object { $_.Command -eq $Command } | Select-Object -First 1
    $BoundArgs = $Callstack.InvocationInfo.BoundParameters

    # Return if we got nothing
    if (-not $BoundArgs) {
        return $null
    }

    # Return early if nothing to filter
    if (-not $Include -and -not $Exclude) {
        return $BoundArgs
    }

    $BoundArgs.GetEnumerator() | Where-Object {
        $IsIncluded = if ($Include) { $_.Key -in $Include } else { $True }
        $IsExcluded = if ($Exclude) { $_.Key -in $Exclude } else { $False }
        if ($IsIncluded -and -not $IsExcluded) {
            Write-Output $_
        }
    }
}
