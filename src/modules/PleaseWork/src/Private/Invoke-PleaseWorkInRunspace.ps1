<#
.SYNOPSIS
    Invokes PleaseWork in a dedicated runspace.
#>
function Invoke-PleaseWorkInRunspace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModulePath,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $InvocationParameters,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory
    )

    $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $PowerShell = [powershell]::Create()
    try {
        $Runspace.Open()
        $PowerShell.Runspace = $Runspace
        $InvocationScript = {
            param ($ImportedModulePath, $Parameters, $InitialWorkingDirectory)

            Set-Location -LiteralPath $InitialWorkingDirectory
            $PleaseWorkModule = Import-Module `
                -Name $ImportedModulePath `
                -Force `
                -PassThru `
                -ErrorAction Stop
            $TaskFilePath = $Parameters.TaskFile
            $Declarations = @(& $PleaseWorkModule {
                    param ($Path)

                    Get-TaskFileDeclaration -Path $Path
                } $TaskFilePath)
            if ($Declarations.Count -eq 0) {
                throw "TaskFile '$TaskFilePath' does not declare any tasks."
            }

            $script:PleaseWorkRunspaceDeclarations = @{}
            $script:PleaseWorkRunspaceTasks = [System.Collections.Generic.List[hashtable]]::new()
            $RunspaceTaskInvoker = {
                param ($TaskScriptBlock, $TaskContext, $TaskArguments)

                $ErrorActionPreference = 'Stop'
                foreach ($VariableName in $TaskContext.Keys) {
                    if ($VariableName -eq 'ErrorActionPreference') {
                        continue
                    }
                    Set-Variable `
                        -Name ([string] $VariableName) `
                        -Value $TaskContext[$VariableName] `
                        -Scope Local
                }

                if ($TaskArguments -is [System.Collections.IDictionary]) {
                    & $TaskScriptBlock @TaskArguments
                } elseif ($null -ne $TaskArguments) {
                    [object[]] $PositionalArguments = @($TaskArguments)
                    & $TaskScriptBlock @PositionalArguments
                } else {
                    & $TaskScriptBlock
                }
            }
            $TaskCommand = {
                [CmdletBinding()]
                param (
                    [Parameter(ValueFromRemainingArguments)]
                    [object[]] $Arguments
                )

                $Declaration = $script:PleaseWorkRunspaceDeclarations[$MyInvocation.MyCommand.Name]
                $script:PleaseWorkRunspaceTasks.Add(@{
                    Name = $Declaration.Name
                    Help = $Declaration.Help
                    Dependencies = $Declaration.Dependencies
                    PathSpecs = $Declaration.PathSpecs
                    ScriptBlock = $Arguments[-1]
                })
            }
            foreach ($Declaration in $Declarations) {
                $script:PleaseWorkRunspaceDeclarations[$Declaration.CommandToken] = $Declaration
                Set-Item `
                    -LiteralPath "Function:global:$($Declaration.CommandToken)" `
                    -Value $TaskCommand
            }

            $OriginalErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $null = @(. $TaskFilePath)
            } finally {
                $ErrorActionPreference = $OriginalErrorActionPreference
            }

            $ConfigVariable = Get-Variable `
                -Name PleaseConfig `
                -Scope Local `
                -ErrorAction SilentlyContinue
            $TaskConfig = if ($null -eq $ConfigVariable) {
                @{}
            } elseif (-not ($ConfigVariable.Value -is [System.Collections.IDictionary])) {
                throw '$PleaseConfig must be a dictionary.'
            } else {
                $ConfigVariable.Value
            }

            $HelpTask = @($script:PleaseWorkRunspaceTasks | Where-Object { $_.Name -ieq 'help' })
            $OverrideHelp = $TaskConfig.Contains('OverrideHelp') -and
                $TaskConfig['OverrideHelp'] -eq $true
            if ($HelpTask.Count -gt 0 -and -not $OverrideHelp) {
                throw "Task 'help' is reserved. Set `$PleaseConfig.OverrideHelp = `$true to override it."
            }

            $TasksByName = [System.Collections.Generic.Dictionary[string, hashtable]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )
            foreach ($TaskDefinition in $script:PleaseWorkRunspaceTasks) {
                if ($TasksByName.ContainsKey($TaskDefinition.Name)) {
                    throw "Task '$($TaskDefinition.Name)' is declared more than once."
                }
                $TasksByName.Add($TaskDefinition.Name, $TaskDefinition)
            }
            $PreparedTaskSet = [pscustomobject] @{
                DefaultTask = if ($env:PLEASE_DEFAULT_TASK) {
                    $env:PLEASE_DEFAULT_TASK
                } else {
                    $script:PleaseWorkRunspaceTasks[0].Name
                }
                TaskNames = [string[]] $script:PleaseWorkRunspaceTasks.Name
                Tasks = $TasksByName
                Config = $TaskConfig
                Module = $null
                Invoker = $RunspaceTaskInvoker
            }
            & $PleaseWorkModule {
                param ($TaskSet)

                $script:PreparedTaskSet = $TaskSet
            } $PreparedTaskSet
            Invoke-PleaseWork @Parameters
        }
        $null = $PowerShell.AddScript($InvocationScript.ToString())
        $null = $PowerShell.AddArgument($ModulePath)
        $null = $PowerShell.AddArgument($InvocationParameters)
        $null = $PowerShell.AddArgument($WorkingDirectory)

        $Output = [System.Collections.Generic.List[psobject]]::new()
        $InvocationError = $null
        try {
            $null = $PowerShell.Invoke($null, $Output)
        } catch {
            $InvocationError = $PowerShell.InvocationStateInfo.Reason
            if ($null -eq $InvocationError) {
                $InvocationError = $_.Exception.InnerException
            }
        }

        foreach ($InformationRecord in $PowerShell.Streams.Information) {
            $PSCmdlet.WriteInformation($InformationRecord)
        }
        foreach ($WarningRecord in $PowerShell.Streams.Warning) {
            $PSCmdlet.WriteWarning($WarningRecord.Message)
        }
        foreach ($VerboseRecord in $PowerShell.Streams.Verbose) {
            $PSCmdlet.WriteVerbose($VerboseRecord.Message)
        }
        foreach ($DebugRecord in $PowerShell.Streams.Debug) {
            $PSCmdlet.WriteDebug($DebugRecord.Message)
        }
        foreach ($ProgressRecord in $PowerShell.Streams.Progress) {
            $PSCmdlet.WriteProgress($ProgressRecord)
        }
        $Output

        if ($null -ne $InvocationError) {
            throw $InvocationError
        }
        if ($PowerShell.InvocationStateInfo.State -eq 'Failed') {
            throw $PowerShell.InvocationStateInfo.Reason
        }
    } finally {
        $PowerShell.Dispose()
        $Runspace.Dispose()
    }
}
