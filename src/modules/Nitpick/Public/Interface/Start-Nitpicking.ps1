<#
.SYNOPSIS
    Powershell first replacement for PSScriptAnalyzer
#>
function Start-Nitpicking {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [Alias('nitpick', 'np')]
    param(
        [Parameter(Mandatory,ParameterSetName='Path',ValueFromPipeline)]
        [string] $Path,

        [Parameter(Mandatory,ParameterSetName='Script')]
        [string] $Script,

        [string[]] $CustomRulePath,

        [string[]] $Include,
        [string[]] $Exclude
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            # todo
        } else {
            # todo
        }
    }
}
