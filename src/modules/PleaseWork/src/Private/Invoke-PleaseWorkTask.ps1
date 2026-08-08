using namespace System.Collections.Generic
using namespace System.Management.Automation

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
        [object[]] $Arguments,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Context,

        [Parameter(Mandatory)]
        [ref] $Result
    )

    $Variables = [List[PSVariable]]::new()
    $Variables.Add(
        [PSVariable]::new('ErrorActionPreference', 'Stop')
    )
    foreach ($VariableName in $Context.Keys) {
        if ($VariableName -eq 'ErrorActionPreference') {
            continue
        }
        $Variables.Add(
            [PSVariable]::new(
                [string] $VariableName,
                $Context[$VariableName]
            )
        )
    }

    $StartedAt = [datetime]::UtcNow
    $global:LASTEXITCODE = 0
    try {
        # InvokeWithContext returns collected output only after successful completion. If the
        # scriptblock terminates, output written before the error is not available to the caller.
        $ScriptBlock.InvokeWithContext($null, $Variables, $Arguments)
    } catch {
        $TaskError = $_
        $TaskException = $_.Exception
        if ($null -ne $TaskException.InnerException) {
            $TaskException = $TaskException.InnerException
            if ($TaskException -is [System.Management.Automation.RuntimeException] -and
                $null -ne $TaskException.ErrorRecord
            ) {
                $TaskError = $TaskException.ErrorRecord
            }
        }

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
        throw $TaskException
    }

    $FinishedAt = [datetime]::UtcNow
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
