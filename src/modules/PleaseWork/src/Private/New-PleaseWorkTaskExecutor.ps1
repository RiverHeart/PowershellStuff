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
        [System.Collections.IDictionary] $Parameters = @{},

        [Parameter()]
        [System.Collections.IDictionary] $Variables = @{},

        [Parameter()]
        [string] $WorkingDirectory
    )

    $Runspace = $null
    $PowerShell = $null
    try {
        # The parameterless factory provides the session state in which module auto-loading works
        # consistently for both Windows PowerShell 5.1 and PowerShell 7.
        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $Runspace.Open()

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
        throw
    }

    return $PowerShell
}
