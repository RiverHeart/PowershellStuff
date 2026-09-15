<#
.SYNOPSIS
    Asserts property details on an object.

.DESCRIPTION
    Calls Test-Property and throws when the specified property does not satisfy
    the requested constraints.

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
    [OutputType([void])]
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

    if (-not (Test-Property @PSBoundParameters)) {
        throw "Property '$Name' failed validation."
    }
}
