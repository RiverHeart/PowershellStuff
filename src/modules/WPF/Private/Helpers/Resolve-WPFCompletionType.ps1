<#
.SYNOPSIS
    Resolves a completion type from a keyword/control name.

.DESCRIPTION
    Resolves a .NET type used by `$this` completion.

    Resolution order:
    1) Custom mappings registered with Register-WPFCompletionType
    2) Built-in WPF type lookup via Get-WPFTypeInfo
#>
function Resolve-WPFCompletionType {
    [CmdletBinding()]
    [OutputType([type])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $Registry = Get-WPFCompletionTypeRegistry
    $LookupName = if ($Name -ieq 'App') { 'Window' } else { $Name }

    foreach ($Entry in $Registry.GetEnumerator()) {
        if ([string] $Entry.Key -ieq $LookupName) {
            $EntryValue = $Entry.Value
            if ($EntryValue -and $EntryValue.PSObject.Properties['Type']) {
                return $EntryValue.Type
            }

            if ($EntryValue -is [type]) {
                return $EntryValue
            }

            break
        }
    }

    $Type = @(Get-WPFTypeInfo -Name $LookupName) | Select-Object -First 1
    if ($Type -is [type]) {
        return $Type
    }

    return $null
}
