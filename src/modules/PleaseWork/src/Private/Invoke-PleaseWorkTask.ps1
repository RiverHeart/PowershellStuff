using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Invokes one task in a disposable runspace created from a Task Snapshot.

.DESCRIPTION
    Recreates task and helper definitions in a fresh runspace, executes the task,
    records its result, replays task streams, and disposes all task session state.

.PARAMETER Name
    The task name.

.PARAMETER Snapshot
    The Task Snapshot that contains the task definition and setup state.

.PARAMETER Arguments
    Arguments for the requested task.

.PARAMETER Context
    PleaseWork context injected into the task.

.PARAMETER Result
    Receives the task result.

.PARAMETER WorkingDirectory
    Working directory for the task.

.EXAMPLE
    Invoke-PleaseWorkTask -Name build -Snapshot $Snapshot -Context @{} -Result ([ref] $Result)

    Runs one task and records it in $Result.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function Invoke-PleaseWorkTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject] $Snapshot,

        [AllowNull()]
        [object] $Arguments,

        [Parameter(Mandatory)]
        [IDictionary] $Context,

        [Parameter(Mandatory)]
        [ref] $Result,

        [Parameter()]
        [PSCmdlet] $StreamCaller = $PSCmdlet,

        [Parameter()]
        [string] $WorkingDirectory
    )

    $TaskDefinition = @($Snapshot.Tasks | Where-Object Name -eq $Name)[0]
    if ($null -eq $TaskDefinition) {
        throw "Task '$Name' is not present in the Task Snapshot."
    }

    $InvocationScript = {
        param (
            [string] $TaskScript,
            [System.Collections.IDictionary] $TaskContext,
            [System.Collections.IDictionary] $TaskConfig,
            [AllowNull()]
            [object] $TaskArguments
        )

        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Stop'
        $private:PleaseWorkModule = Get-Module PleaseWork | Select-Object -First 1
        & $private:PleaseWorkModule {
            param ($Config)
            $script:PleaseWorkConfig = $Config
        } $TaskConfig
        $private:TaskScriptBlock = [scriptblock]::Create($TaskScript)
        $private:InvocationContext = $TaskContext
        $private:InvocationArguments = $TaskArguments

        Remove-Variable `
            -Name TaskScript, TaskContext, TaskArguments, TaskConfig, PleaseWorkModule `
            -Scope Local

        foreach ($VariableName in $private:InvocationContext.Keys) {
            Set-Variable `
                -Name ([string] $VariableName) `
                -Value $private:InvocationContext[$VariableName] `
                -Scope Local
        }

        try {
            if ($private:InvocationArguments -is [System.Collections.IDictionary]) {
                & $private:TaskScriptBlock @private:InvocationArguments
            } elseif ($null -ne $private:InvocationArguments) {
                [object[]] $private:PositionalArguments = @($private:InvocationArguments)
                & $private:TaskScriptBlock @private:PositionalArguments
            } else {
                & $private:TaskScriptBlock
            }
        } finally {
            $global:PleaseWorkTaskExitCode = $global:LASTEXITCODE
        }
    }

    $InitialSessionState = New-PleaseWorkInitialSessionState -Snapshot $Snapshot
    $IsolatedConfig = Copy-PleaseWorkSnapshotValue `
        -InputObject $Snapshot.Config `
        -Name PleaseConfig

    $IsolatedContext = Copy-PleaseWorkSnapshotValue `
        -InputObject $Context `
        -Name TaskContext

    $Executor = $null
    $Runspace = $null
    $StartedAt = [datetime]::UtcNow
    $TaskError = $null
    $Output = @()
    try {
        $Executor = New-PleaseWorkTaskExecutor `
            -ScriptBlock $InvocationScript `
            -Parameters @{
                TaskScript = $TaskDefinition.ScriptBlockText
                TaskContext = $IsolatedContext
                TaskConfig = $IsolatedConfig
                TaskArguments = $Arguments
            } `
            -InitialSessionState $InitialSessionState `
            -WorkingDirectory $WorkingDirectory

        $Runspace = $Executor.Runspace

        $InvocationOutput = [PSDataCollection[psobject]]::new()
        try {
            $Executor.Invoke($null, $InvocationOutput)
        } catch {
            $TaskError = @($Executor.Streams.Error) | Select-Object -Last 1

            if ($null -eq $TaskError) {
                $TaskError = $Executor.InvocationStateInfo.Reason
            }

            if ($null -eq $TaskError) {
                $TaskError = $_.Exception.InnerException
            }

            if ($null -eq $TaskError) {
                $TaskError = $_
            }

            while ($null -ne $TaskError) {
                $ErrorException = if ($TaskError -is [ErrorRecord]) {
                    $TaskError.Exception
                } else {
                    $TaskError
                }

                $InnerError = $ErrorException.PSObject.Properties['ErrorRecord'].Value
                if ($null -eq $InnerError -or $InnerError -eq $TaskError) {
                    break
                }
                $TaskError = $InnerError
            }
            if ($TaskError -is [Exception]) {
                $TaskError = [ErrorRecord]::new(
                    $TaskError,
                    'PleaseWorkIsolatedTaskFailed',
                    [ErrorCategory]::OperationStopped,
                    $Name
                )
            }
        }
        $Output = @($InvocationOutput)

        Write-PleaseWorkTaskExecutorStream -Executor $Executor -Caller $StreamCaller
    } finally {
        $FinishedAt = [datetime]::UtcNow
        $ExitCode = 0
        if ($null -ne $Runspace) {
            $ExitCodeValue = $Runspace.SessionStateProxy.GetVariable(
                'PleaseWorkTaskExitCode'
            )

            if ($null -ne $ExitCodeValue) {
                $ExitCode = [int] $ExitCodeValue
            }

            $Runspace.Dispose()
        }

        if ($null -ne $Executor) { $Executor.Dispose() }

        $Result.Value = [pscustomobject] @{
            TaskName = $Name
            Succeeded = $null -eq $TaskError -and $ExitCode -eq 0
            ExitCode = $ExitCode
            Error = $TaskError
            StartedAt = $StartedAt
            FinishedAt = $FinishedAt
            Duration = $FinishedAt - $StartedAt
            Output = $Output
        }
        $global:LASTEXITCODE = $ExitCode
    }

    Write-Output -InputObject $Output

    if ($null -ne $TaskError) {
        throw $TaskError
    }
}
