<#
.SYNOPSIS
    Asserts property details on an object.

.DESCRIPTION
    Checks if the specified property exists on the input object and validates
    its type, nullability, and emptiness based on the provided parameters.

.EXAMPLE
    Basic usage

    $Object = @{ Name = 'Example' }
    Assert-Property -InputObject $Object -Has 'Name' -Is [string]

.EXAMPLE
    Using the Matches parameter

    $Object = @{ Name = 'Example' }
    Assert-Property -InputObject $Object -Has 'Name' -Matches '^Ex'
#>
function Assert-Property {
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
        if ($Optional) {
            return $true
        }
        Write-Error "Object must include a '$Name' property." -Category ObjectNotFound
        return $false
    }
    if ($Is -and $InputObject.$Name -isnot $Is) {
        throw "Property '$Name' must be of type '$Is'."
    }
    if ($IsAny -and ($InputObject.$Name -isnot $IsAny)) {
        $MatchFound = $false
        foreach($Type in $IsAny) {
            if ($InputObject.$Name -is $Type) {
                $MatchFound = $true
                break
            }
        }
        if (-not $MatchFound) {
            throw "Property '$Name' must be one of the types: $($IsAny -join ', ')."
        }
    }
    if (-not $AllowNull -and $null -eq $InputObject.$Name) {
        throw "Property '$Name' cannot be null."
    }
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($InputObject.$Name)) {
        throw "Property '$Name' cannot be null or empty."
    }
    if ($Matches -and $InputObject.$Name -notmatch $Matches) {
        throw "Property '$Name' does not match the pattern '$Matches'."
    }
}
