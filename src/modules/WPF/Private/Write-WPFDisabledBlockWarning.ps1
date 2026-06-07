<#
.SYNOPSIS
    Writes a warning message indicating that a WPF block has been disabled.

.EXAMPLE
    -StackPanel 'MyPanel' { ...code... }

    This will skip the StackPanel block and write a warning indicating that it was disabled.
#>
function Write-WPFDisabledBlockWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.InvocationInfo] $Invocation,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $Name
    )

    $DisplayName = if (
        [string]::IsNullOrWhiteSpace($Name) -or
        $Name.TrimStart().StartsWith('{')
    ) {
        '<unnamed>'
    } else {
        $Name
    }

    Write-Warning "Skipping disabled block for type '$($Invocation.MyCommand.Name)' with name '$DisplayName'."
}
