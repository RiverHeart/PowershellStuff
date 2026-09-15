<#
.SYNOPSIS
    Creates the shared context for a planned task invocation.
#>
function New-PleaseWorkTaskContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TaskFilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TaskFileRoot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $TaskOrder,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Tasks,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config
    )

    $TaskContext = @{
        TaskFilePath = $TaskFilePath
        TaskFileRoot = $TaskFileRoot
    }

    if (@($TaskOrder | Where-Object { $Tasks[$_].PathSpecs.Count -gt 0 }).Count -gt 0) {
        $BaseRef = if ($Config.Contains('BaseRef')) {
            [string] $Config['BaseRef']
        } else {
            $null
        }
        if ([string]::IsNullOrWhiteSpace($BaseRef)) {
            throw @"
Tasks using changed() require a non-empty `$PleaseConfig.BaseRef.
For example, to run tasks based on changes in the current branch relative to the main branch, set:

    `$PleaseConfig = @{ BaseRef = 'origin/main' }
"@
        }
        $HeadRef = if ($Config.Contains('HeadRef')) {
            [string] $Config['HeadRef']
        } else {
            'HEAD'
        }
        $Changeset = Get-GitChangeset `
            -WorkingDirectory $TaskFileRoot `
            -BaseRef $BaseRef `
            -HeadRef $HeadRef
        $TaskContext.Changeset = $Changeset
        $TaskContext.GitRoot = $Changeset.Root
    } elseif (Get-Command 'git' -ErrorAction SilentlyContinue) {
        $GitRoot = git -C $TaskFileRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            $TaskContext.GitRoot = [string] @($GitRoot)[0]
        }
    }

    return $TaskContext
}
