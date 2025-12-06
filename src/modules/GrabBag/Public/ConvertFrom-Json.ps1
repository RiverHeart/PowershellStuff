if ($PSEdition -eq 'Core') {
    return
}

Write-Host "Creating a proxy for ConvertFrom-Json to add -AsHashtable support on Windows PowerShell"

function ConvertFrom-Json {
    [CmdletBinding(HelpUri='https://go.microsoft.com/fwlink/?LinkID=217031', RemotingCapability='None')]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [AllowEmptyString()]
        [string]
        ${InputObject},

        [switch]
        ${AsHashtable}
    )

    begin
    {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\ConvertFrom-Json', [System.Management.Automation.CommandTypes]::Cmdlet)
            if ($PSBoundParameters.ContainsKey(('AsHashtable'))) {
                $PSBoundParameters.Remove('AsHashtable') | Out-Null
                $scriptCmd = {& $wrappedCmd @PSBoundParameters | Convert-PSObjectToHashtable }
            } else {
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            $steppablePipeline.Process(($_ -replace '\n\s*\/\/.*', '')) # Strip JS-style comments
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
}
