using namespace System.Collections.Generic

<#
.SYNOPSIS
    Loads task declarations from a TaskFile.
#>
function Read-TaskFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $TaskFileScript = [scriptblock]::Create([System.IO.File]::ReadAllText($ResolvedPath))
    $Declarations = @(Get-TaskDeclaration -ScriptBlock $TaskFileScript)

    if ($Declarations.Count -eq 0) {
        throw "TaskFile '$ResolvedPath' does not declare any tasks."
    }

    # Keep the TaskFile definition scope alive after this function returns. Dot-sourcing
    # into the module binds the original task bodies to its variables and functions.
    $TaskFileModule = New-Module `
        -ArgumentList $TaskFileScript, $Declarations, $function:Task `
        -ErrorAction Stop `
        -ScriptBlock {
            param ($ScriptBlock, $TaskDeclarations, $TaskRegistrar)

            $script:RegisteredTasks = [List[hashtable]]::new()
            foreach ($Declaration in $TaskDeclarations) {
                $TaskName = $Declaration.Name
                $TaskHelp = $Declaration.Help
                $TaskDependencies = $Declaration.Dependencies
                $TaskPathSpecs = $Declaration.PathSpecs
                $TaskCommand = {
                    [CmdletBinding()]
                    param (
                        [Parameter(ValueFromRemainingArguments)]
                        [object[]] $Arguments
                    )

                    & $TaskRegistrar `
                        -Name $TaskName `
                        -Help $TaskHelp `
                        -Registry $script:RegisteredTasks `
                        -Dependencies $TaskDependencies `
                        -PathSpecs $TaskPathSpecs `
                        -ScriptBlock $Arguments[-1]
                }.GetNewClosure()

                Set-Item -LiteralPath "Function:$($Declaration.CommandToken)" -Value $TaskCommand
            }

            $BoundScriptBlock = $ExecutionContext.SessionState.Module.NewBoundScriptBlock($ScriptBlock)
            $ErrorActionPreference = 'Stop'
            $null = @(. $BoundScriptBlock)
        }
    $Tasks = @(& $TaskFileModule { $script:RegisteredTasks })
    $TaskConfig = & $TaskFileModule {
        $ConfigVariable = Get-Variable -Name PleaseConfig -Scope Script -ErrorAction SilentlyContinue
        if ($null -eq $ConfigVariable) {
            return @{}
        }
        if (-not ($ConfigVariable.Value -is [System.Collections.IDictionary])) {
            throw '$PleaseConfig must be a dictionary.'
        }
        return $ConfigVariable.Value
    }
    $TasksByName = [Dictionary[string, hashtable]]::new([StringComparer]::OrdinalIgnoreCase)

    $HelpTask = @($Tasks | Where-Object { $_.Name -ieq 'help' })
    $OverrideHelp = $TaskConfig.Contains('OverrideHelp') -and
        $TaskConfig['OverrideHelp'] -eq $true
    if ($HelpTask.Count -gt 0 -and -not $OverrideHelp) {
        throw "Task 'help' is reserved. Set `$PleaseConfig.OverrideHelp = `$true to override it."
    }

    foreach ($TaskDefinition in $Tasks) {
        if ($TasksByName.ContainsKey($TaskDefinition.Name)) {
            throw "Task '$($TaskDefinition.Name)' is declared more than once."
        }

        $TasksByName.Add($TaskDefinition.Name, $TaskDefinition)
    }

    return [pscustomobject] @{
        DefaultTask = if ($env:PLEASE_DEFAULT_TASK) { $env:PLEASE_DEFAULT_TASK } else { $Tasks[0].Name }
        TaskNames = [string[]] $Tasks.Name
        Tasks = $TasksByName
        Config = $TaskConfig
        Module = $TaskFileModule
    }
}
