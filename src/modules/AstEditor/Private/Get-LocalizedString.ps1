<#
.SYNOPSIS
    Retrieves a localized string for the specified key and optional arguments.

.DESCRIPTION
    This function looks up the localized string corresponding to the provided key
    in the module's language resource files. If arguments are supplied, they are
    used to format the string.

.PARAMETER Key
    The key identifying the localized string.

.PARAMETER Args
    Optional arguments to format the localized string.

.EXAMPLE
    Retrieve the localized string by key and format it with arguments.

    $Message = Get-LocalizedString -Key 'OutsideFragment' -Args 0, 5, 1, 4
    Write-Host $Message
#>
function Get-LocalizedString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter()]
        [object[]] $Args
    )

    if ($null -eq $Script:Strings) {
        throw [InvalidOperationException]::new("Localization strings not loaded.")
    }

    if (-not $Script:Strings.ContainsKey($Key)) {
        throw [InvalidOperationException]::new("Localization key '$Key' not found.")
    }

    $Script:Strings[$Key] -f $Args
}
