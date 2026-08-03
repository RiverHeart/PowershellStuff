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
        [AllowNull()]
        [System.Management.Automation.Language.CommentHelpInfo] $Help,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[hashtable]] $Registry,

        [Parameter(ValueFromRemainingArguments)]
        [object[]] $Arguments
    )

    if ($Arguments.Length -eq 0) {
        throw 'At least one argument (the scriptblock) is required.'
    }

    $ScriptBlock = $Arguments[-1]
    if (-not ($ScriptBlock -is [scriptblock])) {
        throw [System.ArgumentException]::new('The last argument must be a scriptblock.')
    }

    if ($Arguments.Length -gt 1) {
        [string[]] $Dependencies = $Arguments[0..($Arguments.Length - 2)]
    } else {
        [string[]] $Dependencies = @()
    }

    $Registry.Add(@{
        Name = $Name
        Help = $Help
        Dependencies = $Dependencies
        ScriptBlock = $ScriptBlock
    })
}
