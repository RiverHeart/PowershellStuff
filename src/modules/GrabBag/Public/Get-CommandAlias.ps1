<#
.SYNOPSIS
    Convenience function to get all aliases associated with a command.

.DESCRIPTION
    Convenience function to get all aliases associated with a command.

.EXAMPLE
    Get-CommandAlias Get-ChildItem
#>
function Get-CommandAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Command
    )

    return Get-Alias | Where-Object { $_.ResolvedCommandName -match $Command }
}
