using namespace System.Collections
using namespace System.Management.Automation.Runspaces

<#
.SYNOPSIS
    Creates a PowerShell pipeline in a new PleaseWork runspace.
#>
function New-PleaseWorkTaskExecutor {
    [CmdletBinding()]
    [OutputType([powershell])]
    param (
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [IDictionary] $Parameters = @{},

        [Parameter()]
        [IDictionary] $Variables = @{},

        [Parameter()]
        [InitialSessionState] $InitialSessionState,

        [Parameter()]
        [string] $WorkingDirectory
    )

    $Runspace = $null
    $PowerShell = $null
    $OriginalPSModulePath = $env:PSModulePath
    try {
        # The parameterless factory provides the session state in which module auto-loading works
        # consistently for both Windows PowerShell 5.1 and PowerShell 7.
        $Runspace = if ($null -eq $InitialSessionState) {
            [RunspaceFactory]::CreateRunspace()
        } else {
            [RunspaceFactory]::CreateRunspace(
                $InitialSessionState
            )
        }

        try {
            $Runspace.Open()
        } finally {
            $env:PSModulePath = $OriginalPSModulePath
        }

        foreach ($Variable in $Variables.GetEnumerator()) {
            $Runspace.SessionStateProxy.SetVariable([string] $Variable.Key, $Variable.Value)
        }

        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            $null = $Runspace.SessionStateProxy.Path.SetLocation($WorkingDirectory)
        }

        $PowerShell = [powershell]::Create()
        $PowerShell.Runspace = $Runspace
        $null = $PowerShell.AddScript($ScriptBlock.ToString())
        $null = $PowerShell.AddParameters($Parameters)
    } catch {
        if ($null -ne $PowerShell) { $PowerShell.Dispose() }
        if ($null -ne $Runspace) { $Runspace.Dispose() }
        $env:PSModulePath = $OriginalPSModulePath

        throw
    }

    return $PowerShell
}
