<#
.SYNOPSIS
    Invokes one task with explicit context and records its result.
#>
function Invoke-PleaseWorkTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [AllowNull()]
        [object] $Arguments,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Context,

        [AllowNull()]
        [scriptblock] $Invoker,

        [Parameter(Mandatory)]
        [ref] $Result
    )

    # Standard TaskFiles bind task bodies to a dynamic module. This wrapper runs there so context
    # variables remain invocation-local while the call operator preserves normal parameter binding.
    $TaskInvoker = {
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

    $StartedAt = [datetime]::UtcNow
    $global:LASTEXITCODE = 0
    try {
        # Direct-runspace TaskFiles supply an invoker created in their own script scope. Standard
        # TaskFiles instead enter the dynamic module associated with the task scriptblock.
        if ($null -ne $Invoker) {
            & $Invoker $ScriptBlock $Context $Arguments
        } elseif ($null -ne $ScriptBlock.Module) {
            & $ScriptBlock.Module $TaskInvoker $ScriptBlock $Context $Arguments
        } else {
            & $TaskInvoker $ScriptBlock $Context $Arguments
        }
    } catch {
        $TaskError = $_

        $FinishedAt = [datetime]::UtcNow
        $Result.Value = [pscustomobject] @{
            TaskName = $Name
            Succeeded = $false
            ExitCode = [int] $global:LASTEXITCODE
            Error = $TaskError
            StartedAt = $StartedAt
            FinishedAt = $FinishedAt
            Duration = $FinishedAt - $StartedAt
        }
        throw  # Re-throw the error to propagate it to the caller.
    }

    $FinishedAt = [datetime]::UtcNow
    # Task-local LASTEXITCODE assignments do not affect the native status tracked by the runspace.
    $ExitCode = [int] $global:LASTEXITCODE
    $Result.Value = [pscustomobject] @{
        TaskName = $Name
        Succeeded = $ExitCode -eq 0
        ExitCode = $ExitCode
        Error = $null
        StartedAt = $StartedAt
        FinishedAt = $FinishedAt
        Duration = $FinishedAt - $StartedAt
    }
}
