<#
.SYNOPSIS
    Registers a completion type mapping for a DSL keyword/control name.

.DESCRIPTION
    Adds or replaces a mapping used by `$this` completion to resolve the .NET
    type for custom DSL keywords.

.EXAMPLE
    Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.TextBlock])
#>
function Register-WPFCompletionType {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [type] $Type,

        [switch] $Force
    )

    $Registry = Get-WPFCompletionTypeRegistry

    $ExistingEntry = $null
    foreach ($Entry in $Registry.GetEnumerator()) {
        if ([string] $Entry.Key -ieq $Name) {
            $ExistingEntry = $Entry
            break
        }
    }

    if ($ExistingEntry -and -not $Force) {
        Write-Error "Register-WPFCompletionType: A mapping for '$Name' already exists. Use -Force to replace it."
        return
    }

    if ($ExistingEntry) {
        $null = $Registry.Remove($ExistingEntry.Key)
    }

    $Mapping = [pscustomobject] @{
        Name = $Name
        Type = $Type
    }

    $Registry[$Name] = $Mapping

    if ($script:WPFThisCompletionCache -and $script:WPFThisCompletionCache.Completions) {
        $null = $script:WPFThisCompletionCache.Completions.Remove($Name)
    }

    return $Mapping
}
