<#
.SYNOPSIS
    Replays buffered executor streams through the calling cmdlet.
#>
function Write-PleaseWorkTaskExecutorStream {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [powershell] $Executor,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $Caller
    )

    foreach ($InformationRecord in $Executor.Streams.Information) {
        $Caller.WriteInformation($InformationRecord)
    }
    foreach ($WarningRecord in $Executor.Streams.Warning) {
        $Caller.WriteWarning($WarningRecord.Message)
    }
    foreach ($VerboseRecord in $Executor.Streams.Verbose) {
        $Caller.WriteVerbose($VerboseRecord.Message)
    }
    foreach ($DebugRecord in $Executor.Streams.Debug) {
        $Caller.WriteDebug($DebugRecord.Message)
    }
    foreach ($ProgressRecord in $Executor.Streams.Progress) {
        $Caller.WriteProgress($ProgressRecord)
    }
}
