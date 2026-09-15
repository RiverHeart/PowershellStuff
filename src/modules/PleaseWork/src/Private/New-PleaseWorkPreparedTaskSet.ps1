using namespace System.Collections.Generic

<#
.SYNOPSIS
    Validates registered tasks and prepares them for the PleaseWork planner.
#>
function New-PleaseWorkPreparedTaskSet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[hashtable]] $Tasks,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config,

        [Parameter(Mandatory)]
        [scriptblock] $Invoker
    )

    $HelpTask = @($Tasks | Where-Object { $_.Name -ieq 'help' })
    $OverrideHelp = $Config.Contains('OverrideHelp') -and $Config.OverrideHelp -eq $true

    if ($HelpTask.Count -gt 0 -and -not $OverrideHelp) {
        throw "Task 'help' is reserved. Set `$PleaseConfig.OverrideHelp = `$true to override it."
    }

    $TasksByName = [Dictionary[string, hashtable]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($TaskDefinition in $Tasks) {
        if ($TasksByName.ContainsKey($TaskDefinition.Name)) {
            throw "Task '$($TaskDefinition.Name)' is declared more than once."
        }
        $TasksByName.Add($TaskDefinition.Name, $TaskDefinition)
    }

    return [pscustomobject] @{
        DefaultTask = if ($env:PLEASE_DEFAULT_TASK) {
            $env:PLEASE_DEFAULT_TASK
        } else {
            $Tasks[0].Name
        }
        TaskNames = [string[]] $Tasks.Name
        Tasks = $TasksByName
        Config = $Config
        Module = $null
        Invoker = $Invoker
    }
}
