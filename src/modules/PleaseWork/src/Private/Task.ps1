using namespace System.Collections.Generic

<#
.SYNOPSIS
    Registers one task definition without writing it to the output pipeline.
#>
function Task {
    [CmdletBinding(PositionalBinding=$false)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [AllowEmptyString()]
        [string] $Description,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.Language.CommentHelpInfo] $Help,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[hashtable]] $Registry,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $Dependencies = @(),

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $PathSpecs = @(),

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $Registry.Add(@{
        Name = $Name
        Description = if ([string]::IsNullOrWhiteSpace($Description)) { $null } else { $Description }
        Help = $Help
        Dependencies = $Dependencies
        PathSpecs = $PathSpecs
        ScriptBlock = $ScriptBlock
    })
}
