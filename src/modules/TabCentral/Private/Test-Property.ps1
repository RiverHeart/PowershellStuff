<#
.SYNOPSIS
    Tests property details on an object.

.DESCRIPTION
    Returns whether the specified property exists and satisfies the requested
    type, nullability, emptiness, and pattern constraints.

.EXAMPLE
    $Object = [pscustomobject] @{ Name = 'Example' }
    Test-Property -InputObject $Object -Name Name -Is ([string]) -Matches '^Ex'
#>
function Test-Property {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name,

        [type] $Is,
        [type[]] $IsAny,
        [string] $Matches,
        [switch] $Optional,
        [switch] $AllowNull,
        [switch] $AllowEmpty
    )

    if ($InputObject.PSObject.Properties.Name -notcontains $Name) {
        return [bool] $Optional
    }

    $Value = $InputObject.$Name

    if ($Is -and $Value -isnot $Is) {
        return $false
    }

    if ($IsAny) {
        $MatchFound = $false
        foreach ($Type in $IsAny) {
            if ($Value -is $Type) {
                $MatchFound = $true
                break
            }
        }

        if (-not $MatchFound) {
            return $false
        }
    }

    if ($null -eq $Value) {
        return [bool] $AllowNull
    }

    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    if ($Matches -and $Value -notmatch $Matches) {
        return $false
    }

    return $true
}
