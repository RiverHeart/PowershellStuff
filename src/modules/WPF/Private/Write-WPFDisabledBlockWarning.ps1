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
