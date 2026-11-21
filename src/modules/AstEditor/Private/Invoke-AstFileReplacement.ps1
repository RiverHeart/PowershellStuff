<#
.SYNOPSIS
    Commits a staged file without a destructive overwrite fallback.
#>
function Invoke-AstFileReplacement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $TemporaryPath,

        [Parameter(Mandatory)]
        [string] $TargetPath,

        [switch] $TargetExists
    )

    if ($TargetExists) {
        [System.IO.File]::Replace(
            $TemporaryPath, $TargetPath, [System.Management.Automation.Language.NullString]::Value
        )
    } else {
        [System.IO.File]::Move($TemporaryPath, $TargetPath)
    }
}
